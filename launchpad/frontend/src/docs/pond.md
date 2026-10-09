# Staking: the Pond

Stake $PONDPAD and you get **sPONDPAD**, a share of the Pond. There's nothing to claim: rewards are added to the Pond itself, so each sPONDPAD is slowly worth more $PONDPAD. When you leave, you get your share back, rewards included. No fee to join or leave.

## Where rewards come from

- **40% of every protocol fee** on PondPad (coin trades, the $PONDPAD sale and market) belongs to stakers. It arrives as IMD at **PadBuyer**, which buys $PONDPAD with it in small chunks of at most 25 IMD, at most every 10 minutes, and refuses to buy right after a price jump.
- The market's own fees paid in $PONDPAD (the stakers' 40% of them) and **15% of every trim** (sells above the market's cap) come straight here.

## How it drips

Everything bought waits in the **RewardDripper**, which releases about 1/7 of what it holds per week (smoothed over 7 days), a little at every drip, whatever the volume. Anyone can call `drip()` once enough has built up and gets 10 $PONDPAD for it; the keeper does it hourly. Rewards never drip into an empty Pond.

## The short wait

You can leave from the next **Ethereum** block after you join (Robinhood Chain reports Ethereum's block number), usually within 12 seconds. It stops anyone from flash-borrowing $PONDPAD, catching a drip and leaving in the same transaction. The wait travels with the shares if you move them.

## What we can and can't do

The Pond (the sPONDPAD vault) is owned by the 7-day timelock; the dripper's settings, within fixed bounds (smoothing 1 to 30 days), by the 48-hour timelock. The vault owner can pause staking and leaving for **at most 3 days**, then must wait 4 days before pausing again. It can **never** take staked $PONDPAD or the rewards waiting in the dripper. All owner powers end 12 months after the sale starts.

Rewards depend on how much trading happens. We don't promise a number.
