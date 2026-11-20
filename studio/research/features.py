def facts(m):
    total = m["total_weight"]
    return {"guarantee_success_fraction": f"{m['guaranteed_success_weight']}/{total}",
            "shot_success_fraction": f"{m['shot_success_weight']}/{total}"}
