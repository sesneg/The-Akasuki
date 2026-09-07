// service.bal - REST API for the library system
// bal run - starts on port 8080

import ballerina/http;
import ballerina/time;

map<Asset> assetStore = {};
map<Institution> institutionStore = {};

function init() {
    Institution nust = {
        name: "Namibia University of Science and Technology",
        sites: ["Main Campus - Innovation Lab", "Main Campus - Library"]
    };
    institutionStore[nust.name] = nust;
}

@http:ServiceConfig {
    cors: {
        allowOrigins: ["*"],
        allowMethods: ["GET", "POST", "PUT", "DELETE"],
        allowHeaders: ["Content-Type"]
    }
}
service /library on new http:Listener(8080) {

    // CRUD

    resource function post assets(@http:Payload Asset newAsset) returns Asset|http:Conflict|http:BadRequest {
        if newAsset.assetTag == "" {
            return <http:BadRequest>{body: {message: "assetTag cannot be empty"}};
        }
        if assetStore.hasKey(newAsset.assetTag) {
            return <http:Conflict>{body: {message: "an asset with that tag already exists"}};
        }
        assetStore[newAsset.assetTag] = newAsset;
        return newAsset;
    }

    resource function get assets() returns Asset[] {
        return assetStore.toArray();
    }

    resource function get assets/[string assetTag]() returns Asset|http:NotFound {
        Asset? a = assetStore[assetTag];
        if a is Asset {
            return a;
        }
        return <http:NotFound>{body: {message: "asset not found"}};
    }

    resource function put assets/[string assetTag](@http:Payload Asset updated) returns Asset|http:NotFound {
        if !assetStore.hasKey(assetTag) {
            return <http:NotFound>{body: {message: "asset not found"}};
        }
        assetStore[assetTag] = updated;
        return updated;
    }

    resource function delete assets/[string assetTag]() returns http:Ok|http:NotFound {
        if assetStore.hasKey(assetTag) {
            _ = assetStore.remove(assetTag);
            return <http:Ok>{body: {message: "deleted"}};
        }
        return <http:NotFound>{body: {message: "asset not found"}};
    }

    // filter by campus

    resource function get assets/institution/[string institution](string? site) returns Asset[] {
        Asset[] result = [];
        foreach Asset a in assetStore {
            if a.institution == institution {
                if site is string {
                    if a.site == site {
                        result.push(a);
                    }
                } else {
                    result.push(a);
                }
            }
        }
        return result;
    }

    resource function get assets/site/[string site]() returns Asset[] {
        Asset[] result = [];
        foreach Asset a in assetStore {
            if a.site == site {
                result.push(a);
            }
        }
        return result;
    }

    // overdue check

    resource function get assets/overdue() returns Asset[] {
        string today = time:utcToString(time:utcNow()).substring(0, 10);
        Asset[] result = [];
        foreach Asset a in assetStore {
            boolean isOverdue = false;
            foreach ScheduleEntry s in a.schedules {
                if s.dueDate < today {
                    isOverdue = true;
                }
            }
            if isOverdue {
                result.push(a);
            }
        }
        return result;
    }

    // loan / booking

    resource function post assets/[string assetTag]/loan(@http:Payload LoanRequest req)
            returns Asset|http:NotFound|http:Conflict {
        Asset? found = assetStore[assetTag];
        if found is () {
            return <http:NotFound>{body: {message: "asset not found"}};
        }
        Asset a = found;
        if a.status != AVAILABLE {
            return <http:Conflict>{body: {message: "asset is not available right now"}};
        }
        a.status = LOANED_OUT;
        ScheduleEntry entry = {
            scheduleId: "LOAN-" + a.schedules.length().toString(),
            'type: "BOOKING",
            dueDate: req.dueDate,
            description: "Loaned to " + req.borrower
        };
        a.schedules.push(entry);
        assetStore[assetTag] = a;
        return a;
    }

    resource function post assets/[string assetTag]/returnAsset() returns Asset|http:NotFound {
        Asset? found = assetStore[assetTag];
        if found is () {
            return <http:NotFound>{body: {message: "asset not found"}};
        }
        Asset a = found;
        a.status = AVAILABLE;
        assetStore[assetTag] = a;
        return a;
    }

    // components

    resource function post assets/[string assetTag]/components(@http:Payload Component comp)
            returns Asset|http:NotFound {
        Asset? found = assetStore[assetTag];
        if found is () {
            return <http:NotFound>{body: {message: "asset not found"}};
        }
        Asset a = found;
        a.components.push(comp);
        assetStore[assetTag] = a;
        return a;
    }

    resource function delete assets/[string assetTag]/components/[string compId]()
            returns Asset|http:NotFound {
        Asset? found = assetStore[assetTag];
        if found is () {
            return <http:NotFound>{body: {message: "asset not found"}};
        }
        Asset a = found;
        Component[] keep = [];
        foreach Component c in a.components {
            if c.compId != compId {
                keep.push(c);
            }
        }
        a.components = keep;
        assetStore[assetTag] = a;
        return a;
    }

    // schedules

    resource function post assets/[string assetTag]/schedules(@http:Payload ScheduleEntry sched)
            returns Asset|http:NotFound {
        Asset? found = assetStore[assetTag];
        if found is () {
            return <http:NotFound>{body: {message: "asset not found"}};
        }
        Asset a = found;
        a.schedules.push(sched);
        assetStore[assetTag] = a;
        return a;
    }

    resource function delete assets/[string assetTag]/schedules/[string scheduleId]()
            returns Asset|http:NotFound {
        Asset? found = assetStore[assetTag];
        if found is () {
            return <http:NotFound>{body: {message: "asset not found"}};
        }
        Asset a = found;
        ScheduleEntry[] keep = [];
        foreach ScheduleEntry s in a.schedules {
            if s.scheduleId != scheduleId {
                keep.push(s);
            }
        }
        a.schedules = keep;
        assetStore[assetTag] = a;
        return a;
    }

    // work orders

    resource function post assets/[string assetTag]/workorders(@http:Payload WorkOrder wo)
            returns Asset|http:NotFound {
        Asset? found = assetStore[assetTag];
        if found is () {
            return <http:NotFound>{body: {message: "asset not found"}};
        }
        Asset a = found;
        a.workOrders.push(wo);
        assetStore[assetTag] = a;
        return a;
    }

    resource function put assets/[string assetTag]/workorders/[string orderId](@http:Payload string newStatus)
            returns Asset|http:NotFound {
        Asset? found = assetStore[assetTag];
        if found is () {
            return <http:NotFound>{body: {message: "asset not found"}};
        }
        Asset a = found;
        WorkOrder[] updated = [];
        foreach WorkOrder wo in a.workOrders {
            WorkOrder w = wo;
            if w.orderId == orderId {
                w.status = newStatus;
            }
            updated.push(w);
        }
        a.workOrders = updated;
        assetStore[assetTag] = a;
        return a;
    }

    resource function delete assets/[string assetTag]/workorders/[string orderId]()
            returns Asset|http:NotFound {
        Asset? found = assetStore[assetTag];
        if found is () {
            return <http:NotFound>{body: {message: "asset not found"}};
        }
        Asset a = found;
        WorkOrder[] keep = [];
        foreach WorkOrder wo in a.workOrders {
            if wo.orderId != orderId {
                keep.push(wo);
            }
        }
        a.workOrders = keep;
        assetStore[assetTag] = a;
        return a;
    }

    resource function post assets/[string assetTag]/workorders/[string orderId]/tasks(
            @http:Payload WorkOrderTask task) returns Asset|http:NotFound {
        Asset? found = assetStore[assetTag];
        if found is () {
            return <http:NotFound>{body: {message: "asset not found"}};
        }
        Asset a = found;
        WorkOrder[] updated = [];
        foreach WorkOrder wo in a.workOrders {
            WorkOrder w = wo;
            if w.orderId == orderId {
                w.tasks.push(task);
            }
            updated.push(w);
        }
        a.workOrders = updated;
        assetStore[assetTag] = a;
        return a;
    }

    // institutions

    resource function get institutions() returns Institution[] {
        return institutionStore.toArray();
    }

    resource function post institutions(@http:Payload Institution inst) returns Institution|http:Conflict {
        if institutionStore.hasKey(inst.name) {
            return <http:Conflict>{body: {message: "institution already registered"}};
        }
        institutionStore[inst.name] = inst;
        return inst;
    }

    resource function delete institutions/[string name]() returns http:Ok|http:NotFound {
        if institutionStore.hasKey(name) {
            _ = institutionStore.remove(name);
            return <http:Ok>{body: {message: "removed"}};
        }
        return <http:NotFound>{body: {message: "institution not found"}};
    }
}
