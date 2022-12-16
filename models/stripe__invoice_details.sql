{{ config(enabled=var('stripe__using_invoices', True)) }}

with invoice as (

    select *
    from {{ var('invoice') }}  

), charge as (

    select *
    from {{ var('charge') }}  

), invoice_line_item as (

    select
        invoice_id,
        source_relation,
        plan_id,
        price_id,
        count(distinct unique_id) as number_of_line_items,
        sum(quantity) as total_quantity

    from {{ var('invoice_line_item') }}  
    group by 1,2,3,4

), customer as (

    select *
    from {{ var('customer') }}  

{% if var('stripe__using_subscriptions', True) %}

), subscription as (

    select *
    from {{ var('subscription') }}  

), pricing as (

    select *
    from {{ var('pricing') }}  

{% endif %}
)

select 
    invoice.invoice_id,
    invoice.number as invoice_number,
    invoice.created_at as invoice_created_at,
    invoice.period_start,
    invoice.period_end,
    invoice.status,
    invoice.due_date,
    invoice.currency,
    invoice.amount_due,
    invoice.amount_paid,
    invoice.subtotal,
    invoice.tax,
    invoice.total,
    invoice.amount_remaining,
    invoice.attempt_count,
    invoice.description as invoice_memo,
    invoice_line_item.number_of_line_items,
    invoice_line_item.total_quantity,
    charge.balance_transaction_id,
    charge.amount as charge_amount, 
    charge.status as charge_status,
    charge.connected_account_id, 
    charge.created_at as charge_created_at,
    charge.is_refunded as charge_is_refunded,
    customer.customer_id,
    customer.description as customer_description,
    customer.account_balance as customer_account_balance,
    customer.currency as customer_currency,
    customer.is_delinquent as customer_is_delinquent,
    customer.email as customer_email,
    
    {% if var('stripe__using_subscriptions', True) %}
    subscription.subscription_id,
    subscription.billing as subscription_billing,
    subscription.start_date_at as subscription_start_date,
    subscription.ended_at as subscription_ended_at,

    {% endif %}

    {% if var('stripe__invoice_metadata',[]) %}
    {{ fivetran_utils.pivot_json_extract(string = 'metadata', list_of_properties = var('stripe__invoice_metadata')) }},
    {% endif %}

    invoice.source_relation

from invoice

left join invoice_line_item 
    on invoice.invoice_id = invoice_line_item.invoice_id
    and invoice.source_relation = invoice_line_item.source_relation

left join charge 
    on charge.charge_id = invoice.charge_id
    and charge.invoice_id = invoice.invoice_id
    and charge.source_relation = invoice.source_relation

{% if var('stripe__using_subscriptions', True) %}
left join subscription
    on invoice.subscription_id = subscription.subscription_id
    and invoice.source_relation = subscription.source_relation

{% endif %}


left join customer 
    on invoice.customer_id = customer.customer_id
    and invoice.source_relation = customer.source_relation