// client.bal - CLI client for the library API
// bal run - connects to http://localhost:8080/library

import ballerina/http;
import ballerina/io;

http:Client libraryApi = check new ("http://localhost:8080/library");

public function main() returns error? {
    boolean keepGoing = true;

    while keepGoing {
        showMenu();
        string choice = io:readln("Choice: ").trim();

        if choice == "1" {
            check viewAllAssets();
        } else if choice == "2" {
            check viewByCampus();
        } else if choice == "3" {
            check viewOverdue();
        } else if choice == "4" {
            check loanAnAsset();
        } else if choice == "5" {
            check addASchedule();
        } else if choice == "6" {
            check addNewAsset();
        } else if choice == "0" {
            keepGoing = false;
        } else {
            io:println("Not a valid option, try again.");
        }
        io:println("");
    }

    io:println("Bye!");
}

function showMenu() {
    io:println("----- Library Management Client -----");
    io:println("1. View all assets");
    io:println("2. View assets for a campus");
    io:println("3. View overdue items");
    io:println("4. Loan / book an asset");
    io:println("5. Add a schedule to an asset");
    io:println("6. Register a new asset");
    io:println("0. Quit");
}

function viewAllAssets() returns error? {
    Asset[] assets = check libraryApi->/assets;
    if assets.length() == 0 {
        io:println("No assets yet.");
        return;
    }
    foreach Asset a in assets {
        io:println(a.assetTag + " - " + a.name + " (" + a.status + ") at " + a.institution);
    }
}

function viewByCampus() returns error? {
    string institution = io:readln("Institution name: ").trim();
    string site = io:readln("Site (leave blank for all sites): ").trim();

    Asset[] assets;
    if site == "" {
        assets = check libraryApi->/assets/institution/[institution];
    } else {
        assets = check libraryApi->/assets/institution/[institution](site = site);
    }

    if assets.length() == 0 {
        io:println("Nothing found for that campus.");
        return;
    }
    foreach Asset a in assets {
        io:println(a.assetTag + " - " + a.name + " (" + a.status + ")");
    }
}

function viewOverdue() returns error? {
    Asset[] overdue = check libraryApi->/assets/overdue;
    if overdue.length() == 0 {
        io:println("Nothing overdue right now.");
        return;
    }
    foreach Asset a in overdue {
        io:println("OVERDUE: " + a.assetTag + " - " + a.name);
    }
}

function loanAnAsset() returns error? {
    string assetTag = io:readln("Asset tag: ").trim();
    string borrower = io:readln("Borrower name: ").trim();
    string dueDate = io:readln("Due date (YYYY-MM-DD): ").trim();

    Asset|http:ClientError result = libraryApi->/assets/[assetTag]/loan.post({borrower: borrower, dueDate: dueDate});
    if result is Asset {
        io:println("Loaned " + result.assetTag + " to " + borrower);
    } else {
        io:println("Could not loan asset: " + result.message());
    }
}

function addASchedule() returns error? {
    string assetTag = io:readln("Asset tag: ").trim();
    string scheduleId = io:readln("Schedule id: ").trim();
    string scheduleType = io:readln("Type (MAINTENANCE/BOOKING/SERVICE): ").trim();
    string dueDate = io:readln("Due date (YYYY-MM-DD): ").trim();
    string description = io:readln("Description: ").trim();

    ScheduleEntry entry = {scheduleId: scheduleId, 'type: scheduleType, dueDate: dueDate, description: description};
    Asset|http:ClientError result = libraryApi->/assets/[assetTag]/schedules.post(entry);
    if result is Asset {
        io:println("Schedule added. Total schedules now: " + result.schedules.length().toString());
    } else {
        io:println("Could not add schedule: " + result.message());
    }
}

function addNewAsset() returns error? {
    string assetTag = io:readln("New asset tag: ").trim();
    string name = io:readln("Name: ").trim();
    string description = io:readln("Description: ").trim();
    string institution = io:readln("Institution: ").trim();
    string site = io:readln("Site: ").trim();
    string dateAcquired = io:readln("Date acquired (YYYY-MM-DD): ").trim();

    Asset newAsset = {
        assetTag: assetTag,
        name: name,
        description: description,
        institution: institution,
        site: site,
        status: "AVAILABLE",
        dateAcquired: dateAcquired
    };

    Asset|http:ClientError result = libraryApi->/assets.post(newAsset);
    if result is Asset {
        io:println("Created asset " + result.assetTag);
    } else {
        io:println("Could not create asset: " + result.message());
    }
}

type Asset record {
    string assetTag;
    string name;
    string description;
    string institution;
    string site;
    string status;
    string dateAcquired;
    ScheduleEntry[] schedules = [];
};

type ScheduleEntry record {
    string scheduleId;
    string 'type;
    string dueDate;
    string description;
};
