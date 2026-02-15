--------------------------------------------------Cursor------------------------------------------------------------
--Cursor: Print Extra Charges for Active Subscriptions
--Business Purpose
-- Iterates through active subscriptions and prints extra charges
-- Helps monitor over-limit customers before billing cycle
-- Used for financial review & billing validation

declare @sub_id int
declare @extra decimal(10,2)

DECLARE sub_cursor cursor for
select subscription_id
from Subscription
where status = 'active'

open sub_cursor
fetch next from sub_cursor into @sub_id
while @@FETCH_STATUS = 0
begin
    set @extra = dbo.fn_CalculateExtraCharges(@sub_id)
    if @extra > 0
    begin print 'Subscription ID: ' + cast(@sub_id AS VARCHAR) + ' | Extra Charges: ' + cast(@extra AS VARCHAR)
    end
    fetch next from sub_cursor into @sub_id
end
close sub_cursor
deallocate sub_cursor
--------------------------------------------------------------------------------------------------------------------
--Cursor: Warning for Low Remaining Usage
--Prints warning messages for subscriptions that are close to exhausting their usage limits
--Business Purpose:
-- Detects subscriptions close to usage limits
-- Early warning system before over-usage
-- Supports proactive customer communication

go
declare @sub_id int
declare @remaining_minutes int
declare @remaining_sms int
declare @remaining_data int

declare warn_cursor cursor for
select subscription_id
from Subscription
where status = 'active'

open warn_cursor
fetch next from warn_cursor into @sub_id
while @@FETCH_STATUS = 0
begin
    select 
        @remaining_minutes = remaining_minutes,
        @remaining_sms = remaining_sms,
        @remaining_data = remaining_data
    from fn_RemainingUsage(@sub_id)
    if @remaining_minutes < 50 
       or @remaining_sms < 10
       or @remaining_data < 100
    begin
        print 'Warning for subscription: ' + cast(@sub_id as varchar)
    end
    fetch next from warn_cursor into @sub_id
end
close warn_cursor
deallocate warn_cursor
--------------------------------------------------------------------------------------------------------------------














