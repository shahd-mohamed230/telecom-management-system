
---------------------------------------Rules = Triggers-----------------------------------------------
use [Telecom  System]
---------------------------------------SIM Lifecycle Automation------------------------------------------------------
--(1) Rule: When the first Subscription is activated → the SIM becomes Active
CREATE or Alter TRIGGER trg_SIM_Activate_OnFirstActiveSub
ON Subscription
AFTER INSERT
AS
BEGIN
    UPDATE sim
    SET 
        sim.Status = 'Active',
        sim.ActivationDate = GETDATE()
    FROM SIM_Card sim
    JOIN inserted i 
        ON sim.SIM_ID = i.SIM_ID
    WHERE i.status = 'active'
      AND sim.Status <> 'Active';
END

--(2) If there is no active subscription on the SIM → it will Suspend
CREATE or Alter TRIGGER trg_SIM_Suspend_WhenNoActiveSub
ON Subscription
AFTER UPDATE
AS
BEGIN
    UPDATE sim
    SET sim.Status = 'Suspended'
    FROM SIM_Card sim
    JOIN inserted i 
        ON sim.SIM_ID = i.SIM_ID
    WHERE NOT EXISTS (
        SELECT 1
        FROM Subscription s
        WHERE s.SIM_ID = sim.SIM_ID
          AND s.status = 'active'
    )
END

---------------------------------------Subscription Integrity Rules------------------------------------------------------
--(1) Prevent having more than one active subscription for the same SIM on the same time
CREATE or Alter TRIGGER trg_Prevent_Overlapping_Subscriptions
ON Subscription
INSTEAD OF INSERT
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM Subscription s
        JOIN inserted i
            ON s.SIM_ID = i.SIM_ID
        WHERE 
            s.start_date <= ISNULL(i.end_date, '9999-12-31')
            AND ISNULL(s.end_date, '9999-12-31') >= i.start_date
    )
    BEGIN
        RAISERROR('Subscription period overlaps with an existing subscription for this SIM.',16,1);
        RETURN
    END

    INSERT INTO Subscription (SIM_ID, plan_id, start_date, end_date, status)
    SELECT SIM_ID, plan_id, start_date, end_date, status
    FROM inserted;
END
---------------------------------------Usage Monitoring------------------------------------------------------

--(1) Rule: Usage is prevented after the limit
--in real life, The blocking happens in the Network Layer, not in the Database Trigger
CREATE OR ALTER TRIGGER trg_Block_OverUsage
ON Usage_Records
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN Subscription s ON i.subscription_id = s.subscription_id
        JOIN ServicePlan p ON s.plan_id = p.plan_id
        WHERE i.data_used > p.data_limit
           OR i.minutes_used > p.minutes_limit
           OR i.sms_used > p.sms_limit
    )
    BEGIN
        RAISERROR('Usage exceeds plan limit. Operation blocked.',16,1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END


--(2) Log attempt to use after limit
CREATE TABLE Usage_Event_Log (
    event_id INT IDENTITY(1,1) PRIMARY KEY,
    subscription_id INT NOT NULL,
    event_type VARCHAR(30) NOT NULL DEFAULT 'Blocked',
    usage_date DATE NOT NULL,
    created_at DATETIME DEFAULT GETDATE(),

    CONSTRAINT FK_UsageEvent_Subscription
        FOREIGN KEY (subscription_id)
        REFERENCES Subscription(subscription_id)
)

CREATE or ALTER TRIGGER trg_Log_Strict_Block
ON Usage_Records
Instead of INSERT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO Usage_Event_Log (subscription_id, event_type, usage_date)
    SELECT 
        i.subscription_id,
        'Blocked',
        i.usage_date
    FROM inserted i
    JOIN Subscription s 
        ON i.subscription_id = s.subscription_id
    JOIN ServicePlan p 
        ON s.plan_id = p.plan_id
    WHERE 
        (
            i.data_used >= p.data_limit
            OR i.minutes_used >= p.minutes_limit
            OR i.sms_used >= p.sms_limit
        )
      
        AND NOT EXISTS (
            SELECT 1
            FROM Usage_Event_Log l
            WHERE l.subscription_id = i.subscription_id
              AND l.usage_date = i.usage_date
        )
END


---------------------------------------Complaint Workflow Automation------------------------------------------------------
--(1) Rule: If the complaint is registered without a status → it will be Open
CREATE or ALTER TRIGGER trg_Complaint_DefaultStatus
ON Complaint
AFTER INSERT
AS
BEGIN
    UPDATE c
    SET c.Status = 'Open'
    FROM Complaint c
    JOIN inserted i
        ON c.Complaint_ID = i.Complaint_ID
    WHERE c.Status IS NULL
END

--(2) Rule: If the complaint is resolved → record the closing date
CREATE or ALTER TRIGGER trg_Set_Complaint_ClosedDate
ON Complaint
AFTER UPDATE
AS
BEGIN
    UPDATE c
    SET ComplaintDate = GETDATE()
    FROM Complaint c
    JOIN inserted i ON c.Complaint_ID = i.Complaint_ID
    JOIN deleted d ON d.Complaint_ID = i.Complaint_ID
    WHERE i.Status = 'Closed'
      AND d.Status <> 'Closed'
END

---------------------------------------Audit Logging on Subscription------------------------------------------------------
CREATE TABLE Subscription_Audit (
    audit_id INT IDENTITY(1,1) PRIMARY KEY,
    subscription_id INT,
    old_status VARCHAR(30),
    new_status VARCHAR(30),
    changed_at DATETIME DEFAULT GETDATE()
)

CREATE or ALTER TRIGGER trg_Audit_Subscription_Status
ON Subscription
AFTER UPDATE
AS
BEGIN
    INSERT INTO Subscription_Audit (subscription_id, old_status, new_status)
    SELECT 
        i.subscription_id,
        d.status,
        i.status
    FROM inserted i
    JOIN deleted d
        ON i.subscription_id = d.subscription_id
    WHERE i.status <> d.status
END
