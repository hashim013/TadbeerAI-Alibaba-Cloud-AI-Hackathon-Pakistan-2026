"""
Domain-specific execution handlers for real business operations.
"""

from agents.execution_handlers.energy_executor import execute_energy_action
from agents.execution_handlers.currency_executor import execute_currency_action
from agents.execution_handlers.stock_market_executor import execute_stock_market_action
from agents.execution_handlers.gold_executor import execute_gold_action
from agents.execution_handlers.logistics_executor import execute_logistics_action
from agents.execution_handlers.finance_executor import execute_finance_action
from agents.execution_handlers.policy_executor import execute_policy_action
from agents.execution_handlers.trade_executor import execute_trade_action
from agents.execution_handlers.supply_chain_executor import execute_supply_chain_action

__all__ = [
    "execute_energy_action",
    "execute_currency_action",
    "execute_stock_market_action",
    "execute_gold_action",
    "execute_logistics_action",
    "execute_finance_action",
    "execute_policy_action",
    "execute_trade_action",
    "execute_supply_chain_action"
]
