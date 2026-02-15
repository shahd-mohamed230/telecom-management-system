
---------------------------------------KPIS = Stored Procedures-----------------------------------------------
--Reporting Stored Procedures not Operational Stored Procedures
use [Telecom  System]
---------------------------------------Customer KPIs----------------------------------------------------------
--(1) KPI: Total Active Customers
--with Business Insight
--Calculated Active Customer base using subscription-level logic to support retention analysis
-- If this number is stable or decreasing → Retention problem
-- If it is increasing → Healthy Growth
CREATE or ALTER PROCEDURE sp_GetActiveCustomersCount
AS
BEGIN
    SELECT COUNT(DISTINCT c.customer_id) AS ActiveCustomers
    FROM Customers c
    JOIN SIM_Card s
        ON c.customer_id = s.CustomerID
    JOIN Subscription sub
        ON s.SIM_ID = sub.SIM_ID
    WHERE sub.status = 'active'
END

--(2) KPI: New Customers per Month
--with Business Insight
--Built monthly customer acquisition KPIs to evaluate marketing effectiveness
--Measures the success of Marketing & Acquisition
--Compares between months (Seasonality)
CREATE or ALTER PROCEDURE sp_GetNewCustomersByMonth
AS
BEGIN
    SELECT 
        YEAR(Registration_Date) AS Year,
        MONTH(Registration_Date) AS Month,
        COUNT(*) AS NewCustomers
    FROM Customers
    GROUP BY 
        YEAR(Registration_Date),
        MONTH(Registration_Date)
    ORDER BY Year, Month
END

--(3) KPI: Customers without Subscription
--with Business Insight
--Identified idle customers representing untapped revenue opportunities
-- Upsell Opportunity or Activation Process Failed or Need a dedicated Campaign
CREATE or ALTER PROCEDURE sp_GetIdleCustomers
AS
BEGIN
    SELECT DISTINCT c.customer_id, c.f_name, c.L_name
    FROM Customers c
    JOIN SIM_Card s
        ON c.customer_id = s.CustomerID
    WHERE NOT EXISTS (
        SELECT 1
        FROM Subscription sub
        WHERE sub.SIM_ID = s.SIM_ID
    )
END

--(4) KPI: Avg Time to First Subscription
--with Business Insight
--Activation delay is measured to improve the customer onboarding process and suppress churn.
--Large number → weak onboarding
--Small number → excellent conversion
CREATE or ALTER PROCEDURE sp_AvgActivationDelay
AS
BEGIN
    WITH FirstSubscription AS (
        SELECT 
            c.customer_id,
            c.Registration_Date,
            MIN(sub.start_date) AS First_Subscription_Date
        FROM Customers c
        JOIN SIM_Card s
            ON c.customer_id = s.CustomerID
        JOIN Subscription sub
            ON s.SIM_ID = sub.SIM_ID
        GROUP BY c.customer_id, c.Registration_Date
    )
    SELECT 
        AVG(DATEDIFF(DAY, Registration_Date, First_Subscription_Date)) 
            AS AvgActivationDelayDays
    FROM FirstSubscription
END

---------------------------------------Revenue KPIs----------------------------------------------------------
--(1)KPI: Monthly Revenue
--with Business Insight
--Calculated monthly revenue trends based on active subscriptions
--The Basis of Any Financial Dashboard: Revenue Growth or Decline (Month-to-Month Comparison)
CREATE or ALTER PROCEDURE sp_MonthlyRevenue
AS
BEGIN
    SELECT 
        YEAR(start_date) AS Year,
        MONTH(start_date) AS Month,
        SUM(p.monthly_fee) AS MonthlyRevenue
    FROM Subscription s
    JOIN ServicePlan p
        ON s.plan_id = p.plan_id
    WHERE s.status = 'active'
    GROUP BY YEAR(start_date), MONTH(start_date)
    ORDER BY Year, Month
END

--(2) KPI: Average Revenue Per User (ARPU)
--with Business Insight
--Derived ARPU metric combining revenue and active customer base to assess customer value
--ARPU measures the quality of customers, not their number.
--It is very useful for comparing plans.
CREATE or ALTER PROCEDURE sp_CalculateARPU
AS
BEGIN
    WITH Revenue AS (
        SELECT 
            YEAR(start_date) AS Year,
            MONTH(start_date) AS Month,
            SUM(p.monthly_fee) AS TotalRevenue
        FROM Subscription s
        JOIN ServicePlan p
            ON s.plan_id = p.plan_id
        WHERE s.status = 'active'
        GROUP BY YEAR(start_date), MONTH(start_date)
    ),
    ActiveCustomers AS (
        SELECT 
            YEAR(sub.start_date) AS Year,
            MONTH(sub.start_date) AS Month,
            COUNT(DISTINCT c.customer_id) AS ActiveCustomers
        FROM Customers c
        JOIN SIM_Card sim ON c.customer_id = sim.CustomerID
        JOIN Subscription sub ON sim.SIM_ID = sub.SIM_ID
        WHERE sub.status = 'active'
        GROUP BY YEAR(sub.start_date), MONTH(sub.start_date)
    )
    SELECT 
        r.Year,
        r.Month,
        CAST(r.TotalRevenue * 1.0 / ac.ActiveCustomers as decimal(10,2)) AS ARPU
    FROM Revenue r
    JOIN ActiveCustomers ac
        ON r.Year = ac.Year AND r.Month = ac.Month
END

--(3) KPI: Revenue per Plan
--with Business Insight
--Analyzed revenue contribution by service plan to support pricing optimization.
--The most used package ≠ the most profitable package
--Decision to cancel or develop packages
CREATE or ALTER PROCEDURE sp_RevenueByPlan
AS
BEGIN
    SELECT 
        p.plan_name,
        COUNT(s.subscription_id) AS ActiveSubscriptions,
        SUM(p.monthly_fee) AS TotalRevenue
    FROM Subscription s
    JOIN ServicePlan p
        ON s.plan_id = p.plan_id
    WHERE s.status = 'active'
    GROUP BY p.plan_name
	order by SUM(p.monthly_fee) desc, COUNT(s.subscription_id) desc
END

--(4) KPI: Lost Revenue (Cancelled)
--with Business Insight
--Quantified revenue loss due to subscription churn to highlight financial impact of customer attrition.
--The cost of Churn
--Links Complaints and Usage to revenue
CREATE or ALTER PROCEDURE sp_LostRevenue
AS
BEGIN
    SELECT 
        YEAR(end_date) AS Year,
        MONTH(end_date) AS Month,
        SUM(p.monthly_fee) AS LostRevenue
    FROM Subscription s
    JOIN ServicePlan p
        ON s.plan_id = p.plan_id
    WHERE s.status = 'Cancelled'
    GROUP BY YEAR(end_date), MONTH(end_date)
    ORDER BY Year, Month
END

---------------------------------------Usage KPIs----------------------------------------------------------

--Over-usage (Upsell)                 Under-usage (Downgrade)                   Churn signals

--(1) KPI: Avg Usage per Plan
--with Business Insight
--Analyzed average usage behavior per plan to evaluate product-market fit
--If the average is close to the limits → the plan is suitable
--If much lower → price is high
--If much higher → Upsell opportunity
CREATE or ALTER PROCEDURE sp_AvgUsageByPlan
AS
BEGIN
    WITH SubscriptionUsage AS (
        SELECT 
            s.subscription_id,
            p.plan_name,
            SUM(u.minutes_used) AS total_minutes,
            SUM(u.data_used) AS total_data,
            SUM(u.sms_used) AS total_sms
        FROM Subscription s
        JOIN ServicePlan p
            ON s.plan_id = p.plan_id
        JOIN Usage_Records u
            ON s.subscription_id = u.subscription_id
        WHERE s.status = 'active'
        GROUP BY s.subscription_id, p.plan_name
    )
    SELECT 
        plan_name,
        AVG(total_minutes) AS avg_minutes,
        AVG(total_data) AS avg_data,
        AVG(total_sms) AS avg_sms
    FROM SubscriptionUsage
    GROUP BY plan_name
END

--(2) KPI: Over-usage Rate
--with Business Insight
--Identified over-usage patterns to support proactive upsell strategies.
--Clients need an upgrade, Network stress, A smart marketing plan
CREATE or ALTER PROCEDURE sp_OverUsageSubscriptions
AS
BEGIN
    WITH UsageSummary AS (
        SELECT 
            s.subscription_id,
            p.plan_name,
            SUM(u.minutes_used) AS total_minutes,
            SUM(u.data_used) AS total_data,
            SUM(u.sms_used) AS total_sms,
            p.minutes_limit,
            p.data_limit,
            p.sms_limit
        FROM Subscription s
        JOIN ServicePlan p ON s.plan_id = p.plan_id
        JOIN Usage_Records u ON s.subscription_id = u.subscription_id
        WHERE s.status = 'active'
        GROUP BY 
            s.subscription_id,
            p.plan_name,
            p.minutes_limit,
            p.data_limit,
            p.sms_limit
    )
    SELECT 
        plan_name,
        COUNT(*) AS OverUsageSubscriptions
    FROM UsageSummary
    WHERE 
        total_minutes > minutes_limit
        OR total_data > data_limit
        OR total_sms > sms_limit
    GROUP BY plan_name
	order by COUNT(*) desc
END

--(3) KPI: Zero Usage Subscriptions
--with Business Insight
--Detected zero-usage active subscriptions as early churn indicators
--Weak onboarding
--High likelihood of cancellation
--Needs follow-up
CREATE or ALTER PROCEDURE sp_ZeroUsage
AS
BEGIN
    SELECT 
        s.subscription_id,
        p.plan_name
    FROM Subscription s
    JOIN ServicePlan p ON s.plan_id = p.plan_id
    WHERE s.status = 'active'
    AND NOT EXISTS (
        SELECT 1
        FROM Usage_Records u
        WHERE u.subscription_id = s.subscription_id
    )
END

---------------------------------------Complaints KPIs----------------------------------------------------------
--(1) KPI: Complaints per Month
--with Business Insight
--Monitored monthly complaint trends to evaluate service quality and operational stability
--Sudden increase = network/service problem
--Comparison before/after operational decisions
CREATE or ALTER PROCEDURE sp_ComplaintsMonthly
AS
BEGIN
    SELECT 
        YEAR(ComplaintDate) AS Year,
        MONTH(ComplaintDate) AS Month,
        COUNT(*) AS TotalComplaints
    FROM Complaint
    GROUP BY YEAR(ComplaintDate), MONTH(ComplaintDate)
    ORDER BY Year, Month
END

--(2) KPI: Complaints per Employee
--with Business Insight
--Analyzed complaint distribution per employee to assess workload balance and operational efficiency.
--Unfair workload distribution?  Overloaded employees
CREATE or ALTER PROCEDURE sp_ComplaintsByEmployee
AS
BEGIN
    SELECT 
        e.employee_id,
        e.f_name,
        e.L_name,
        COUNT(c.Complaint_ID) AS ComplaintsHandled
    FROM Employee e
    LEFT JOIN Complaint c
        ON e.employee_id = c.EmployeeID
    GROUP BY e.employee_id, e.f_name, e.L_name
	order by COUNT(c.Complaint_ID) desc
END

--(3) KPI: Customers with Repeated Complaints
--with Business Insight
--Flagged customers with repeated complaints as high churn-risk segments.
--High-risk customers in terms of churn
--Require special intervention
--Direct link to Lost Revenue
CREATE or ALTER PROCEDURE sp_RepeatedComplaints
AS
BEGIN
    SELECT 
        c.customer_id,
        c.f_name,
        c.L_name,
        COUNT(comp.Complaint_ID) AS ComplaintsCount
    FROM Customers c
    JOIN Complaint comp
        ON c.customer_id = comp.CustomerID
    GROUP BY c.customer_id, c.f_name, c.L_name
    HAVING COUNT(comp.Complaint_ID) > 1
END

