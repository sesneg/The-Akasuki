// types.bal - data models for the library system

public final string AVAILABLE = "AVAILABLE";
public final string LOANED_OUT = "LOANED_OUT";
public final string OCCUPIED = "OCCUPIED";
public final string UNDER_MAINTENANCE = "UNDER_MAINTENANCE";
public final string DISPOSED = "DISPOSED";

// part of a bigger asset, e.g. a printer motor
public type Component record {
    string compId;
    string name;
    string description;
};

// maintenance / booking entry for an asset
public type ScheduleEntry record {
    string scheduleId;
    string 'type;
    string dueDate;
    string description;
};

// one task inside a work order
public type WorkOrderTask record {
    string taskId;
    string description;
    boolean completed = false;
};

// fault/repair ticket for an asset
public type WorkOrder record {
    string orderId;
    string status;
    string description;
    WorkOrderTask[] tasks = [];
};

// main resource record - book, laptop, room, etc.
public type Asset record {
    string assetTag;
    string name;
    string description;
    string institution;
    string site;
    string status = AVAILABLE;
    string dateAcquired;
    Component[] components = [];
    ScheduleEntry[] schedules = [];
    WorkOrder[] workOrders = [];
};

public type Institution record {
    string name;
    string[] sites = [];
};

public type ErrorDetail record {
    string message;
};

public type LoanRequest record {
    string borrower;
    string dueDate;
};
