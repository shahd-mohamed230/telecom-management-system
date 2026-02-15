--1) window function

--top 5 customer usage data.

SELECT top 5
    c.customer_id,
    c.f_name+' ' +c.l_name as fullname,
    SUM(u.data_used) AS total_data_used,
    RANK() OVER (ORDER BY SUM(u.data_used) DESC) AS data_usage_rank
FROM Customers c
JOIN SIM_Card sc ON c.customer_id = sc.CustomerID
JOIN Subscription s ON sc.SIM_ID = s.SIM_ID
JOIN Usage_Records u ON s.subscription_id = u.subscription_id
GROUP BY c.customer_id, c.f_name, c.l_name;



--employee based on number of complaint 
SELECT
    e.employee_id,
    e.f_name+' '+e.l_name as fullname,
    COUNT(c.Complaint_ID) AS total_complaints,
    DENSE_RANK() OVER (ORDER BY COUNT(c.Complaint_ID) DESC) AS workload_rank
FROM Employee e
LEFT JOIN Complaint c ON e.employee_id = c.EmployeeID
GROUP BY e.employee_id, e.f_name, e.l_name;
-------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------
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


-------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------

--3) view 

--> View Active_Subscriptions


CREATE VIEW vw_Active_Subscriptions
AS
SELECT
    c.customer_id,
    c.f_name,
    c.l_name,
    sc.SIM_Number,
    sp.plan_name,
    s.start_date,
    s.end_date
FROM Customers c
JOIN SIM_Card sc ON c.customer_id = sc.CustomerID
JOIN Subscription s ON sc.SIM_ID = s.SIM_ID
JOIN ServicePlan sp ON s.plan_id = sp.plan_id
WHERE s.status = 'active';

select * from vw_Active_Subscriptions





--> View OverUsage Subscriptions for active cst



CREATE VIEW vw_OverUsage_Subscriptions
AS
SELECT
    s.subscription_id,
    sp.plan_name,
    sp.minutes_limit,
    sp.data_limit,
    sp.sms_limit,

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

FROM Subscription s
JOIN ServicePlan sp ON s.plan_id = sp.plan_id
LEFT JOIN Usage_Records u ON s.subscription_id = u.subscription_id

WHERE s.status = 'active'

GROUP BY
    s.subscription_id,
    sp.plan_name,
    sp.minutes_limit,
    sp.data_limit,
    sp.sms_limit;

        
select * from vw_OverUsage_Subscriptions




-------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------

--4) Integrity

--> Invalid Usage without subscription.

CREATE VIEW vw_Invalid_Usage
AS
SELECT
    u.usage_id,
    u.subscription_id
FROM Usage_Records u
LEFT JOIN Subscription s
    ON u.subscription_id = s.subscription_id
WHERE s.subscription_id IS NULL;


select * from vw_Invalid_Usage




-------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------

--5) driven


--> total_bill

go

SELECT
    s.subscription_id,
    sp.plan_name,
    sp.monthly_fee,
    sp.minutes_limit,
    SUM(u.minutes_used) AS total_minutes,
    sp.data_limit,
    SUM(u.data_used) AS total_data,
    sp.sms_limit,
    SUM(u.sms_used) AS total_sms,

    
    CASE 
        WHEN SUM(u.minutes_used) > sp.minutes_limit
        THEN (SUM(u.minutes_used) - sp.minutes_limit) * 0.25
        ELSE 0
    END AS extra_minutes_cost,

    CASE 
        WHEN SUM(u.data_used) > sp.data_limit
        THEN (SUM(u.data_used) - sp.data_limit) * 0.01
        ELSE 0
    END AS extra_data_cost,

    CASE 
        WHEN SUM(u.sms_used) > sp.sms_limit
        THEN (SUM(u.sms_used) - sp.sms_limit) * 0.5
        ELSE 0
    END AS extra_sms_cost,

   
    sp.monthly_fee
    +
    CASE 
        WHEN SUM(u.minutes_used) > sp.minutes_limit
        THEN (SUM(u.minutes_used) - sp.minutes_limit) * 0.25
        ELSE 0
    END
    +
    CASE 
        WHEN SUM(u.data_used) > sp.data_limit
        THEN (SUM(u.data_used) - sp.data_limit) * 0.01
        ELSE 0
    END
    +
    CASE 
        WHEN SUM(u.sms_used) > sp.sms_limit
        THEN (SUM(u.sms_used) - sp.sms_limit) * 0.5
        ELSE 0
    END

    AS total_bill

FROM Subscription s
JOIN ServicePlan sp ON s.plan_id = sp.plan_id
LEFT JOIN Usage_Records u ON s.subscription_id = u.subscription_id

WHERE s.status = 'active'

GROUP BY
    s.subscription_id,
    sp.plan_name,
    sp.monthly_fee,
    sp.minutes_limit,
    sp.data_limit,
    sp.sms_limit;












