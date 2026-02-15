---------------------------------------------------Functions--------------------------------------------------------
--Get Service Plan Monthly Price
--Returns the monthly fee of a specific service plan based on the plan ID

create or alter function fn_GetPlanPrice(@plan_id int)
returns int
as
begin
	declare @price int;
	select @price = monthly_fee
	from ServicePlan
	where plan_id = @plan_id;
	return @price;
end

go

select dbo.fn_GetPlanPrice(5)

-------------------------------------------------------------------------------------------------------------------
--Determine Subscription Status
--Returns whether the subscription is Active or Expired based on dates

go
create or alter function fn_SubscriptionStatus(@start_date DATE,@end_date DATE)
returns varchar(20)
as
begin
	if @end_date IS NULL OR @end_date >= GETDATE()
		return 'active';
	return 'expired';
end

go

select subscription_id, dbo.fn_SubscriptionStatus(start_date, end_date) as SubStatus
from Subscription;
-------------------------------------------------------------------------------------------------------------------
--Calculate Total Minutes Usage
--Returns the total minutes used for a specific subscription

go
create or alter function fn_TotalMinutesUsed(@subscription_id int)
returns int
AS
begin
	declare @total_minutes int;
	select @total_minutes = isnull(sum(minutes_used), 0)
	from Usage_Records
	where subscription_id = @subscription_id;
	return @total_minutes;
end
go

SELECT  dbo.fn_TotalMinutesUsed(1007) AS [Total Minutes Used]
-------------------------------------------------------------------------------------------------------------------
--Calculate Total Data Usage
--Returns the total data consumption for a specific subscription

go
create or alter function fn_TotalDataUsed(@subscription_id int)
returns int
as
begin
	declare @total_data int;

	select @total_data = isnull(sum(data_used), 0)
	from Usage_Records
	where subscription_id = @subscription_id;
	return @total_data;
end
go

SELECT  dbo.fn_TotalDataUsed(1007) AS [Total Data Used]

-------------------------------------------------------------------------------------------------------------------
----Calculate Total SMS Usage
--Returns the total SMS usage for a specific subscription

go
create or alter function fn_TotalsmsUsed(@subscription_id int)
returns int
as
begin
	declare @total_sms int;

	select @total_sms= isnull(sum(sms_used), 0)
	from Usage_Records
	where subscription_id = @subscription_id;
	return @total_sms;
end

go


SELECT  dbo.fn_TotalsmsUsed(1007) AS [Total SMS Used]
-------------------------------------------------------------------------------------------------------------------
--Calculate Remaining Usage(Table-Valued)
--Returns the remaining minutes, SMS, and data based on plan limits

go
create or alter function fn_TotalUsed (@subscription_id int)
returns table
as
return
(
    select
        isnull(sum(minutes_used), 0) AS total_minutes,
        isnull(sum(sms_used), 0)     AS total_sms,
        isnull(sum(data_used), 0)    AS total_data
    from Usage_Records
    where subscription_id = @subscription_id
);
go

select* from fn_TotalUsed(1007)

-------------------------------------------------------------------------------------------------------------------
--Calculate Remaining Usage
--Returns the remaining minutes, SMS, and data based on plan limits

go
create or alter function fn_RemainingUsage (@subscription_id int)
returns table
as
return
(
    select
        sp.minutes_limit - isnull(sum(u.minutes_used),0) as remaining_minutes,
        sp.sms_limit     - isnull(sum(u.sms_used),0)     as remaining_sms,
        sp.data_limit    - isnull(sum(u.data_used),0)    as remaining_data
    FROM Subscription s join ServicePlan sp 
			ON s.plan_id = sp.plan_id
     left join Usage_Records u
			ON s.subscription_id = u.subscription_id
    where s.subscription_id = @subscription_id
    group by sp.minutes_limit, sp.sms_limit, sp.data_limit
);
go

select*
from fn_RemainingUsage(1007)
-------------------------------------------------------------------------------------------------------------------
--Check Subscription Limit Status
--Returns 'Over Limit' or 'Within Limit' based on remaining usage
go
create or alter function fn_IsOverLimit(@subscription_id INT)
returns varchar(20)
as
begin
    declare @status VARCHAR(20);

     if exists (
       select 1
        from fn_RemainingUsage(@subscription_id)
        where remaining_minutes < 0
           or remaining_sms < 0
           or remaining_data < 0
    )
        set @status = 'Over Limit';
    else
        set @status = 'Within Limit';

    return @status;
end
go


SELECT  dbo.fn_IsOverLimit(1007) as[Limit Status]
-------------------------------------------------------------------------------------------------------------------
--Calculate Extra Charges
--Returns total extra charges based on exceeded usage
go

create or alter function fn_CalculateExtraCharges(@subscription_id int)
returns decimal (10,2)
as
begin
    declare @extra decimal(10,2) = 0;

    select @extra =
        (case when remaining_minutes < 0 then ABS(remaining_minutes) * 0.5 else 0 end) +
        (case when remaining_sms < 0 then ABS(remaining_sms) * 0.1 else 0 end) +
        (case when remaining_data < 0 then ABS(remaining_data) * 0.05 else 0 end)
    from fn_RemainingUsage(@subscription_id);
    return isnull(@extra,0);
end
go


SELECT  dbo.fn_CalculateExtraCharges(1008) as[Extra Charges]

-------------------------------------------------------------------------------------------------------------------
--Calculate Total Revenue Per Subscription
--Returns total revenue including plan fee and extra charges
go

create or alter function  fn_TotalRevenuePerSubscription(@subscription_id int)
returns decimal (10,2)
as
begin

    declare @total decimal(10,2);
    select @total =
       dbo.fn_GetPlanPrice(plan_id) +
         dbo.fn_CalculateExtraCharges(@subscription_id)
    from Subscription
    where subscription_id = @subscription_id;
    return isnull(@total,0);
end
go

SELECT  dbo.fn_TotalRevenuePerSubscription(1008) as[Total Revenue]

-------------------------------------------------------------------------------------------------------------------








