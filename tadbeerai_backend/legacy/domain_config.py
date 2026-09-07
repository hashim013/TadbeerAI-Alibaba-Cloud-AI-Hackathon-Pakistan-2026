# Business impact formulas per domain
IMPACT_FORMULAS = {
    "Energy": {
        "delivery_cost_per_litre": 5,
        "routes_per_day": 150,
        "working_days": 30,
    },
    "Currency": {
        "import_cost_multiplier": 0.15,
        "typical_import_monthly_pkr": 5_000_000,
    },
    "Gold": {
        "jewellery_making_cost_per_tola": 2000,
        "typical_monthly_procurement_tolas": 50,
    },
    "Logistics": {
        "safety_stock_days_increase": 14,
        "alternate_route_cost_premium": 0.20,
    },
    "Stock Market": {
        "portfolio_hedge_threshold_pct": 3.0,
        "stop_loss_pct": 5.0,
    },
    "Finance": {
        "loan_cost_increase_per_100bps": 0.01,
        "typical_business_loan_pkr": 10_000_000,
    },
    "Policy": {
        "compliance_cost_fixed_pkr": 250_000,
        "audit_fees_pkr": 50_000,
    },
    "Trade": {
        "tariff_increase_pct": 0.10,
        "typical_export_monthly_pkr": 3_000_000,
    },
    "Supply Chain": {
        "delay_days_multiplier": 2,
        "alternate_supplier_premium": 0.18,
    },
}

SIMULATION_ACTIONS = {
    "Energy": [
        {"field": "delivery_fee (Rs.)", "formula": "base + (fuel_increase * 0.8)"},
        {"field": "pricing_version", "formula": "increment_version"},
        {"field": "customers_notified", "formula": "customer_count"},
        {"field": "supplier_flag", "formula": "set_active"},
    ],
    "Currency": [
        {"field": "import_cost_buffer (%)", "formula": "base + rupee_drop_pct * 1.5"},
        {"field": "order_hold_flag", "formula": "set_true"},
        {"field": "vendor_alert", "formula": "set_sent"},
    ],
    "Stock Market": [
        {"field": "portfolio_hedge_flag", "formula": "set_active"},
        {"field": "stop_loss_set", "formula": "set_true"},
        {"field": "risk_alert", "formula": "set_sent"},
    ],
    "Gold": [
        {"field": "procurement_hold", "formula": "set_true"},
        {"field": "alternate_supplier", "formula": "set_identified"},
        {"field": "cost_estimate_increase", "formula": "tola_increase * monthly_procurement"},
    ],
    "Logistics": [
        {"field": "safety_stock_days", "formula": "base + delay_days * 2"},
        {"field": "alternate_route", "formula": "set_express"},
        {"field": "vendor_notified", "formula": "set_true"},
    ],
    "Finance": [
        {"field": "interest_rate_buffer", "formula": "base + rate_hike_pct * 1.0"},
        {"field": "loan_hold_flag", "formula": "set_true"},
        {"field": "finance_alert", "formula": "set_sent"},
    ],
    "Policy": [
        {"field": "compliance_cost", "formula": "base + compliance_cost_fixed"},
        {"field": "audit_pending_flag", "formula": "set_true"},
        {"field": "policy_alert", "formula": "set_sent"},
    ],
    "Trade": [
        {"field": "export_buffer_pct", "formula": "base + tariff_increase_pct * 1.2"},
        {"field": "trade_hold_flag", "formula": "set_true"},
        {"field": "customs_alert", "formula": "set_sent"},
    ],
    "Supply Chain": [
        {"field": "supply_chain_delay_days", "formula": "base + delay_days * 3"},
        {"field": "alternate_supply_active", "formula": "set_true"},
        {"field": "supply_alert", "formula": "set_sent"},
    ],
}
