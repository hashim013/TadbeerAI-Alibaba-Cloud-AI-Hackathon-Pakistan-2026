"""Pytest bootstrap — makes the backend package root importable for tests."""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
