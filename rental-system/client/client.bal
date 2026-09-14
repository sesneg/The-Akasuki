// client.bal - CLI client for the rental gRPC service
// run: bal grpc --input ../proto/rental.proto --output .   then   bal run

import ballerina/grpc;
import ballerina/io;

RentalServiceClient rentalClient = check new ("http://localhost:9090");

public function main() returns error? {
    boolean running = true;
    while running {
        printMenu();
        string choice = io:readln("Select an option: ").trim();
        match choice {
            "1" => { check addProperty(); }
            "2" => { check streamUsers(); }
            "3" => { check updateProperty(); }
            "4" => { check removeProperty(); }
            "5" => { check browseProperties(); }
            "6" => { check searchProperty(); }
            "7" => { check bookProperty(); }
            "8" => { check confirmBooking(); }
            "0" => { running = false; }
            _ => { io:println("Unrecognized option, try again."); }
        }
        io:println("");
    }
    io:println("Goodbye.");
}

function printMenu() {
    io:println("==== Rental Accommodation - gRPC Client ====");
    io:println("1. Add a property listing (Host)");
    io:println("2. Register multiple users (client streaming)");
    io:println("3. Update a property");
    io:println("4. Remove a property");
    io:println("5. Browse available properties (server streaming)");
    io:println("6. Search for a property by ID");
    io:println("7. Book a property (add to cart)");
    io:println("8. Confirm a booking");
    io:println("0. Exit");
}

function addProperty() returns error? {
    string hostId = io:readln("Host ID: ").trim();
    string name = io:readln("Property name: ").trim();
    string location = io:readln("Location: ").trim();
    string ptype = io:readln("Property type (APARTMENT/HOUSE/CABIN): ").trim();
    float price = check float:fromString(io:readln("Price per night: ").trim());
    string region = io:readln("Region: ").trim();

    AddPropertyRequest req = {
        host_id: hostId,
        property_name: name,
        location: location,
        property_type: ptype,
        price_per_night: price,
        status: "AVAILABLE",
        region: region
    };

    Property result = check rentalClient->add_property(req);
    io:println(string `Registered property ${result.property_id}: ${result.property_name}`);
}

function streamUsers() returns error? {
    var streamingClient = check rentalClient->create_users();

    boolean addingMore = true;
    int n = 1;
    while addingMore {
        string more = io:readln(string `Add user #${n}? (y/n): `).trim();
        if more.toLowerAscii() != "y" {
            addingMore = false;
            break;
        }
        string userId = io:readln("  User ID: ").trim();
        string fullName = io:readln("  Full name: ").trim();
        string email = io:readln("  Email: ").trim();
        string role = io:readln("  Role (HOST/GUEST): ").trim();

        check streamingClient->sendUser({user_id: userId, full_name: fullName, email: email, role: role});
        n += 1;
    }

    check streamingClient->complete();
    CreateUsersResponse|grpc:Error? respRaw = streamingClient->receiveCreateUsersResponse();
    if respRaw is grpc:Error {
        return respRaw;
    }
    if respRaw is () {
        io:println("No response received from server.");
        return;
    }
    CreateUsersResponse response = respRaw;
    io:println(string `Server confirmed: ${response.message}`);
}
function updateProperty() returns error? {
    string propertyId = io:readln("Property ID to update: ").trim();
    string priceStr = io:readln("New price (blank to leave unchanged): ").trim();
    string status = io:readln("New status (blank to leave unchanged): ").trim();

    UpdatePropertyRequest req = {property_id: propertyId};
    if priceStr != "" {
        req.price_per_night = check float:fromString(priceStr);
    }
    if status != "" {
        req.status = status;
    }

    Property result = check rentalClient->update_property(req);
    io:println(string `Updated: ${result.property_name} - $${result.price_per_night}/night, status ${result.status}`);
}

function removeProperty() returns error? {
    string propertyId = io:readln("Property ID to remove: ").trim();
    string hostId = io:readln("Host ID: ").trim();

    PropertyList result = check rentalClient->remove_property({property_id: propertyId, host_id: hostId});
    io:println(string `Removed. Host now has ${result.properties.length()} listing(s) remaining in this region:`);
    foreach Property p in result.properties {
        io:println(string `  [${p.property_id}] ${p.property_name} - $${p.price_per_night}/night`);
    }
}

function browseProperties() returns error? {
    string location = io:readln("Filter by location (blank for any): ").trim();
    string minStr = io:readln("Min price (blank for none): ").trim();
    string maxStr = io:readln("Max price (blank for none): ").trim();

    ListPropertiesRequest req = {};
    if location != "" {
        req.location = location;
    }
    if minStr != "" {
        req.min_price = check float:fromString(minStr);
    }
    if maxStr != "" {
        req.max_price = check float:fromString(maxStr);
    }

    stream<Property, grpc:Error?> results = check rentalClient->list_available_properties(req);
    int count = 0;
    check results.forEach(function(Property p) {
        io:println(string `  [${p.property_id}] ${p.property_name} @ ${p.location} - $${p.price_per_night}/night`);
        count += 1;
    });
    if count == 0 {
        io:println("No matching properties.");
    }
}

function searchProperty() returns error? {
    string propertyId = io:readln("Property ID: ").trim();
    SearchPropertyResponse result = check rentalClient->search_property({property_id: propertyId});
    if result.found {
        Property p = result.property;
        io:println(string `${p.property_name} @ ${p.location} - $${p.price_per_night}/night - ${p.status}`);
    } else {
        io:println(result.status_message);
    }
}

function bookProperty() returns error? {
    string guestId = io:readln("Guest ID: ").trim();
    string propertyId = io:readln("Property ID: ").trim();
    string checkIn = io:readln("Check-in (YYYY-MM-DD): ").trim();
    string checkOut = io:readln("Check-out (YYYY-MM-DD): ").trim();

    BookingCartEntry entry = check rentalClient->book_property({
        guest_id: guestId,
        property_id: propertyId,
        check_in: checkIn,
        check_out: checkOut
    });
    io:println(string `Added to cart: ${entry.cart_id}. ${entry.status_message}`);
}

function confirmBooking() returns error? {
    string cartId = io:readln("Cart ID: ").trim();
    string guestId = io:readln("Guest ID: ").trim();

    BookingConfirmation result = check rentalClient->confirm_booking({cart_id: cartId, guest_id: guestId});
    if result.success {
        io:println(string `Booking confirmed: ${result.booking_id}`);
        io:println(string `  ${result.check_in} -> ${result.check_out} (${result.nights} nights) - total $${result.total_cost}`);
    } else {
        io:println(string `Booking failed: ${result.message}`);
    }
}
function updateProperty() returns error? {
    string propertyId = io:readln("Property ID to update: ").trim();
    string priceStr = io:readln("New price (blank to leave unchanged): ").trim();
    string status = io:readln("New status (blank to leave unchanged): ").trim();

    UpdatePropertyRequest req = {property_id: propertyId};
    if priceStr != "" {
        req.price_per_night = check float:fromString(priceStr);
    }
    if status != "" {
        req.status = status;
    }

    Property result = check rentalClient->update_property(req);
    io:println(string `Updated: ${result.property_name} - $${result.price_per_night}/night, status ${result.status}`);
}

function removeProperty() returns error? {
    string propertyId = io:readln("Property ID to remove: ").trim();
    string hostId = io:readln("Host ID: ").trim();

    PropertyList result = check rentalClient->remove_property({property_id: propertyId, host_id: hostId});
    io:println(string `Removed. Host now has ${result.properties.length()} listing(s) remaining in this region:`);
    foreach Property p in result.properties {
        io:println(string `  [${p.property_id}] ${p.property_name} - $${p.price_per_night}/night`);
    }
}

function browseProperties() returns error? {
    string location = io:readln("Filter by location (blank for any): ").trim();
    string minStr = io:readln("Min price (blank for none): ").trim();
    string maxStr = io:readln("Max price (blank for none): ").trim();

    ListPropertiesRequest req = {};
    if location != "" {
        req.location = location;
    }
    if minStr != "" {
        req.min_price = check float:fromString(minStr);
    }
    if maxStr != "" {
        req.max_price = check float:fromString(maxStr);
    }

    stream<Property, grpc:Error?> results = check rentalClient->list_available_properties(req);
    int count = 0;
    check results.forEach(function(Property p) {
        io:println(string `  [${p.property_id}] ${p.property_name} @ ${p.location} - $${p.price_per_night}/night`);
        count += 1;
    });
    if count == 0 {
        io:println("No matching properties.");
    }
}

function searchProperty() returns error? {
    string propertyId = io:readln("Property ID: ").trim();
    SearchPropertyResponse result = check rentalClient->search_property({property_id: propertyId});
    if result.found {
        Property p = result.property;
        io:println(string `${p.property_name} @ ${p.location} - $${p.price_per_night}/night - ${p.status}`);
    } else {
        io:println(result.status_message);
    }
}

function bookProperty() returns error? {
    string guestId = io:readln("Guest ID: ").trim();
    string propertyId = io:readln("Property ID: ").trim();
    string checkIn = io:readln("Check-in (YYYY-MM-DD): ").trim();
    string checkOut = io:readln("Check-out (YYYY-MM-DD): ").trim();

    BookingCartEntry entry = check rentalClient->book_property({
        guest_id: guestId,
        property_id: propertyId,
        check_in: checkIn,
        check_out: checkOut
    });
    io:println(string `Added to cart: ${entry.cart_id}. ${entry.status_message}`);
}

function confirmBooking() returns error? {
    string cartId = io:readln("Cart ID: ").trim();
    string guestId = io:readln("Guest ID: ").trim();

    BookingConfirmation result = check rentalClient->confirm_booking({cart_id: cartId, guest_id: guestId});
    if result.success {
        io:println(string `Booking confirmed: ${result.booking_id}`);
        io:println(string `  ${result.check_in} -> ${result.check_out} (${result.nights} nights) - total $${result.total_cost}`);
    } else {
        io:println(string `Booking failed: ${result.message}`);
    }
}

