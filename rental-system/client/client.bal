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

