def facts(m):
    return {"cash_still_missing_after_guarantee": max(0,m["target"]-m["safe_cash"]),
            "shot_success_percent": m["probability_bp"]/100}
