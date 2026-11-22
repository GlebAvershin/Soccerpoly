#!/usr/bin/env python3
"""Unit tests for Soccerpoly Q-Learning Auction Agent."""
import unittest
from scripts.rl_auction_agent import QLearningAuctionAgent, calculate_opponent_bids, CLUB_TIERS
import random


class TestRLAuctionAgent(unittest.TestCase):
    def setUp(self):
        self.agent = QLearningAuctionAgent(seed=42)

    def test_state_key_generation(self):
        k1 = self.agent.get_state_key(500, "Bronze", 0)
        k2 = self.agent.get_state_key(1800, "Gold", 2)
        self.assertEqual(k1, "cash_0:tier_Bronze:mono_0")
        self.assertEqual(k2, "cash_1:tier_Gold:mono_2")

    def test_q_table_update(self):
        s1 = "cash_1:tier_Gold:mono_1"
        s2 = "cash_1:tier_Gold:mono_2"
        q_before = list(self.agent.get_q_values(s1))
        self.agent.update(s1, 1, 10.0, s2)
        q_after = self.agent.get_q_values(s1)
        self.assertGreater(q_after[1], q_before[1])

    def test_opponent_bids_bounds(self):
        rng = random.Random(42)
        tier_info = CLUB_TIERS["Prestige"]
        nash, agg, opp = calculate_opponent_bids(tier_info, rng)
        self.assertGreater(nash, 0)
        self.assertGreater(agg, 0)
        self.assertGreater(opp, 0)


if __name__ == "__main__":
    unittest.main()
