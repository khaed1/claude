# Button

Buttons say exactly what happens, verb first. `pp-btn-primary` (lily) at most once per view, for the thing the page is for: "Spawn it" on Spawn, "Stake" on the Pond. On the trade box the action button is `pp-btn-buy` or `pp-btn-sell` and names the coin ("Buy $RIBBIT"). `pp-btn-leap` (gold) is only for $PONDPAD (the sale and its market). `pp-btn-ghost` for Cancel and secondary actions; plain `pp-btn` for wallet and neutral actions; `pp-btn-sm` in toolbars; `pp-btn-block` fills its column (trade box, mobile sheets). Pending: disable it and say what is happening ("Laying your egg…"). Minimum touch height 44px (32px for `sm`, desktop toolbars only).

Consumer provides: the label, the click handler, `disabled` while pending.
