import json
import os

from core.paths import get_data_dir

DEFAULT_STATE = {
    "delivery_fee": 150,
    "pricing_version": "v4.1",
    "customer_count": 3200,
    "safety_stock_days": 7,
    "import_cost_buffer": 0,
    "order_hold_flag": False,
    "portfolio_hedge_flag": None,
    "stop_loss_set": False,
    "procurement_hold": False,
    "interest_rate_buffer": 0.0,
    "loan_hold_flag": False,
    "compliance_cost": 0,
    "audit_pending_flag": False,
    "export_buffer_pct": 0.0,
    "trade_hold_flag": False,
    "alternate_supply_active": False,
    "supply_chain_delay_days": 0,
    "fbr_tax_rate": 18.0,
    "sbr_tax_rate": 13.0,
}


class MockDatabase:
    def __init__(self):
        data_dir = get_data_dir()
        os.makedirs(data_dir, exist_ok=True)
        self._db_file = os.path.join(data_dir, "mock_db.json")
        if not os.path.exists(self._db_file):
            with open(self._db_file, "w") as f:
                json.dump(DEFAULT_STATE, f)
        with open(self._db_file) as f:
            self._data = json.load(f)

    def get(self, key: str, default=None):
        return self._data.get(key, default)

    def set(self, key: str, value):
        self._data[key] = value
        with open(self._db_file, "w") as f:
            json.dump(self._data, f)

    def get_state(self, domain: str) -> dict:
        return dict(self._data)

    def get_customer_count(self) -> int:
        return self._data.get("customer_count", 3200)

    def reset(self):
        self._data = dict(DEFAULT_STATE)
        with open(self._db_file, "w") as f:
            json.dump(self._data, f)
