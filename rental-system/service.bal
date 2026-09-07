// service.bal - gRPC server for the rental system
// run: bal grpc --input proto/rental.proto --output .   then   bal run
// listens on localhost:9090

import ballerina/grpc;
import ballerina/time;
import ballerina/uuid;

listener grpc:Listener rentalEp = new (9090);

map<Property> propertyStore = {};
map<User> userStore = {};
map<BookingCartEntry> bookingCart = {};

type DateRange record {
    string checkIn;
    string checkOut;
};
map<DateRange[]> bookedDates = {};

@grpc:Descriptor {value: RENTAL_DESC}
service "RentalService" on rentalEp {

    remote function add_property(AddPropertyRequest req) returns Property|error {
        string newId = uuid:createType1AsString();
        Property p = {
            property_id: newId,
            host_id: req.host_id,
            property_name: req.property_name,
            location: req.location,
            property_type: req.property_type,
            price_per_night: req.price_per_night,
            status: req.status == "" ? "AVAILABLE" : req.status,
            region: req.region
        };
        propertyStore[newId] = p;
        return p;
    }

    remote function create_users(stream<User, grpc:Error?> incomingUsers) returns CreateUsersResponse|error {
        int count = 0;
        error? streamErr = incomingUsers.forEach(function(User u) {
            userStore[u.user_id] = u;
            count = count + 1;
        });
        if streamErr is error {
            return streamErr;
        }
        return {users_created: count, message: count.toString() + " user(s) registered"};
    }

    remote function update_property(UpdatePropertyRequest req) returns Property|error {
        Property? existing = propertyStore[req.property_id];
        if existing is () {
            return error("property not found: " + req.property_id);
        }
        Property p = existing;
        if req.price_per_night is float {
            p.price_per_night = <float>req.price_per_night;
        }
        if req.status is string {
            p.status = <string>req.status;
        }
        propertyStore[req.property_id] = p;
        return p;
    }

    remote function remove_property(RemovePropertyRequest req) returns PropertyList|error {
        Property? existing = propertyStore[req.property_id];
        if existing is () {
            return error("property not found: " + req.property_id);
        }
        Property toRemove = existing;
        if toRemove.host_id != req.host_id {
            return error("this property does not belong to that host");
        }
        _ = propertyStore.remove(req.property_id);

        Property[] remaining = [];
        foreach Property p in propertyStore {
            if p.host_id == req.host_id && p.region == toRemove.region {
                remaining.push(p);
            }
        }
        return {properties: remaining};
    }

    remote function list_available_properties(RentalServicePropertyCaller caller, ListPropertiesRequest req) returns error? {
        foreach Property p in propertyStore {
            if p.status != "AVAILABLE" {
                continue;
            }
            if req.location is string && p.location != <string>req.location {
                continue;
            }
            if req.min_price is float && p.price_per_night < <float>req.min_price {
                continue;
            }
            if req.max_price is float && p.price_per_night > <float>req.max_price {
                continue;
            }
            check caller->sendProperty(p);
        }
        check caller->complete();
    }

    remote function search_property(SearchPropertyRequest req) returns SearchPropertyResponse|error {
        Property? found = propertyStore[req.property_id];
        if found is Property {
            return {found: true, status_message: "Found", property: found};
        }
        Property empty = {
            property_id: "",
            host_id: "",
            property_name: "",
            location: "",
            property_type: "",
            price_per_night: 0.0,
            status: "",
            region: ""
        };
        return {found: false, status_message: "Not Available", property: empty};
    }

    remote function book_property(BookPropertyRequest req) returns BookingCartEntry|error {
        Property? p = propertyStore[req.property_id];
        if p is () {
            return error("property not found: " + req.property_id);
        }
        if req.check_out <= req.check_in {
            return error("check out date must be after check in date");
        }

        string cartId = uuid:createType1AsString();
        BookingCartEntry entry = {
            cart_id: cartId,
            guest_id: req.guest_id,
            property_id: req.property_id,
            check_in: req.check_in,
            check_out: req.check_out,
            status_message: "added to cart, call confirm_booking to finish"
        };
        bookingCart[cartId] = entry;
        return entry;
    }

    remote function confirm_booking(ConfirmBookingRequest req) returns BookingConfirmation|error {
        BookingCartEntry? entry = bookingCart[req.cart_id];
        if entry is () {
            return error("no cart entry with that id");
        }
        if entry.guest_id != req.guest_id {
            return error("this cart entry belongs to a different guest");
        }

        Property? p = propertyStore[entry.property_id];
        if p is () {
            return error("property no longer exists");
        }

        DateRange[] existing = bookedDates[entry.property_id] ?: [];
        foreach DateRange r in existing {
            boolean overlap = entry.check_in < r.checkOut && r.checkIn < entry.check_out;
            if overlap {
                return {
                    success: false,
                    booking_id: "",
                    property_id: entry.property_id,
                    check_in: entry.check_in,
                    check_out: entry.check_out,
                    nights: 0,
                    total_cost: 0.0,
                    message: "those dates are no longer available"
                };
            }
        }

        int nights = countNights(entry.check_in, entry.check_out);
        float total = p.price_per_night * <float>nights;
        string bookingId = uuid:createType1AsString();

        existing.push({checkIn: entry.check_in, checkOut: entry.check_out});
        bookedDates[entry.property_id] = existing;
        _ = bookingCart.remove(req.cart_id);

        return {
            success: true,
            booking_id: bookingId,
            property_id: entry.property_id,
            check_in: entry.check_in,
            check_out: entry.check_out,
            nights: nights,
            total_cost: total,
            message: "booking confirmed"
        };
    }
}

function countNights(string checkIn, string checkOut) returns int {
    time:Utc|time:Error inTime = time:utcFromString(checkIn + "T00:00:00.00Z");
    time:Utc|time:Error outTime = time:utcFromString(checkOut + "T00:00:00.00Z");

    if inTime is time:Error || outTime is time:Error {
        return 0;
    }

    time:Seconds diff = time:utcDiffSeconds(outTime, inTime);
    return <int>(diff / 86400);
}
