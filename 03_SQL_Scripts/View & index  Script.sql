--1) view 

--> View Active_Subscriptions
go

CREATE VIEW vw_Active_Subscriptions
AS
SELECT c.customer_id,c.f_name, c.l_name, sc.SIM_Number, sp.plan_name, s.start_date,
        s.end_date
FROM Customers c JOIN SIM_Card sc 
        ON c.customer_id = sc.CustomerID
    JOIN Subscription s
        ON sc.SIM_ID = s.SIM_ID
    JOIN ServicePlan sp 
        ON s.plan_id = sp.plan_id
WHERE s.status = 'active';

go

select * from vw_Active_Subscriptions

-----------------------------------------------------
--> View OverUsage Subscriptions for active cst
go

CREATE VIEW vw_OverUsage_Subscriptions
AS
SELECT s.subscription_id, sp.plan_name,sp.minutes_limit,sp.data_limit,sp.sms_limit,
    COALESCE(SUM(u.minutes_used),0) AS total_minutes,
    COALESCE(SUM(u.data_used),0) AS total_data,
    COALESCE(SUM(u.sms_used),0) AS total_sms,
    CASE 
        WHEN COALESCE(SUM(u.minutes_used),0) > sp.minutes_limit 
        THEN 'Exceeded'
        ELSE 'Within Limit'
    END AS minutes_status,

    CASE 
        WHEN COALESCE(SUM(u.data_used),0) > sp.data_limit 
        THEN 'Exceeded'
        ELSE 'Within Limit'
    END AS data_status,

    CASE 
        WHEN COALESCE(SUM(u.sms_used),0) > sp.sms_limit 
        THEN 'Exceeded'
        ELSE 'Within Limit'
    END AS sms_status
FROM Subscription s JOIN ServicePlan sp 
    ON s.plan_id = sp.plan_id
LEFT JOIN Usage_Records u 
    ON s.subscription_id = u.subscription_id

WHERE s.status = 'active'

GROUP BY
    s.subscription_id,
    sp.plan_name,
    sp.minutes_limit,
    sp.data_limit,
    sp.sms_limit;
go
        
select * from vw_OverUsage_Subscriptions

-----------------------------------------------------------
--> Invalid Usage without subscription.
go
CREATE VIEW vw_Invalid_Usage
AS
SELECT u.usage_id, u.subscription_id
FROM Usage_Records u LEFT JOIN Subscription s
    ON u.subscription_id = s.subscription_id
WHERE s.subscription_id IS NULL;

go
select * from vw_Invalid_Usage

----------------------------------------------------------
--2) index 

--> by national_id 

CREATE INDEX idx_customers_national_id
ON Customers(national_id);

SELECT *
FROM Customers
WHERE national_id = '750-22-2303';


--> by subscription_id 

CREATE INDEX idx_usage_subscription
ON Usage_Records(subscription_id);


SELECT *
FROM Usage_Records
WHERE subscription_id = 1008;


-- Index on Subscription by SIM_ID

create index idx_subscription_sim
on Subscription(SIM_ID);

select *
from Subscription
where SIM_ID = 5;


















