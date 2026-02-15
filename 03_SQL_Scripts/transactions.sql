---------------------------------------Critical Operations = Transactions-----------------------------------------------
use [Telecom  System]
--(1) Subscription Lifecycle (Activation)
CREATE OR ALTER PROCEDURE sp_CreateSubscription
    @SIM_ID INT,
    @Plan_ID INT,
    @Start_Date DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON; -- auto rollback when error 

    BEGIN TRY
        BEGIN TRANSACTION

        -- 1️ create Subscription
        INSERT INTO Subscription (SIM_ID, plan_id, start_date, status)
        VALUES (@SIM_ID, @Plan_ID, @Start_Date, 'Active');

        -- 2️ active  SIM
        UPDATE SIM_Card
        SET Status = 'Active',
            ActivationDate = ISNULL(ActivationDate, GETDATE())
        WHERE SIM_ID = @SIM_ID

        -- 3️ Log
        INSERT INTO Subscription_Log (SIM_ID, action_type, action_date)
        VALUES (@SIM_ID, 'Activated', GETDATE())

        COMMIT TRANSACTION
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION

        THROW -- give exception 
    END CATCH
END


--(2) Complaint Handling
CREATE OR ALTER PROCEDURE sp_AssignComplaint
    @Complaint_ID INT,
    @Employee_ID INT
AS
BEGIN
    SET NOCOUNT ON
    SET XACT_ABORT ON

    BEGIN TRY
        BEGIN TRANSACTION

        UPDATE Complaint
        SET EmployeeID = @Employee_ID,
            Status = 'Assigned'
        WHERE Complaint_ID = @Complaint_ID;

        INSERT INTO Complaint_Audit
        (Complaint_ID, action_type, action_date)
        VALUES
        (@Complaint_ID, 'Assigned to Employee', GETDATE())

        COMMIT TRANSACTION
    END TRY
    BEGIN CATCH
        ROLLBACK
    END CATCH
END

--(3) Plan Change Transaction
CREATE OR ALTER PROCEDURE sp_ChangePlan
    @Subscription_ID INT,
    @New_Plan_ID INT,
    @Change_Date DATE
AS
BEGIN
    SET NOCOUNT ON
    SET XACT_ABORT ON -- auto rollback when error

    BEGIN TRY
        BEGIN TRANSACTION

        DECLARE @SIM_ID INT

        -- 1️ sim related to current Subscription
        SELECT @SIM_ID = SIM_ID
        FROM Subscription
        WHERE subscription_id = @Subscription_ID
          AND status = 'Active'

        IF @SIM_ID IS NULL
        BEGIN
            RAISERROR('Active subscription not found.',16,1)
            ROLLBACK
            RETURN
        END

        -- 2️ end old Subscription
        UPDATE Subscription
        SET 
            end_date = DATEADD(DAY, -1, @Change_Date),
            status = 'Ended'
        WHERE subscription_id = @Subscription_ID

        -- 3️ create new Subscription
        INSERT INTO Subscription
        (SIM_ID, plan_id, start_date, status)
        VALUES
        (@SIM_ID, @New_Plan_ID, @Change_Date, 'Active')

        -- 4️  Log
        INSERT INTO Subscription_Log
        (SIM_ID, action_type, action_date)
        VALUES
        (@SIM_ID, 'Plan Changed', GETDATE())

        COMMIT TRANSACTION
    END TRY
    BEGIN CATCH
        ROLLBACK
    END CATCH
END