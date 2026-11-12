import { ponder } from "ponder:registry";
import { rawLog } from "ponder:schema";
const EVENTS: Record<string, string[]> = {"PLEA": ["Allowed", "Approval", "Initialized", "Launched", "LetterboxSet", "OwnershipTransferStarted", "OwnershipTransferred", "Transfer"], "CabalGate": ["CabalBegins", "EIP712DomainChanged", "OracleSignerSet", "PleaExpired", "PleaFailed", "PleaFlags", "PleaLapsed", "PleaSubmitted", "SellExecuted", "Verdict"], "Seasons": ["BonusBurned", "BonusPaid", "LeftoverToWall", "PrizeFunded", "PrizePaid", "Recorded", "SeasonClosedOut", "SeatMultiplier"], "PleaDistributor": ["Claimed", "OwnershipTransferStarted", "OwnershipTransferred", "RootSet"], "PleaLaunch": ["HookDeployed", "LetterboxDeployed", "TradingOpened", "TribunalDeployed"], "Letterbox": ["Delivered", "Escrowed", "NameSet", "Settled"], "Tribunal": ["EIP712DomainChanged", "Objected", "ObjectionVoid", "OracleSignerSet", "Ruled", "StakeSettled"], "PleaHook": ["CapRatcheted", "CashbackPaidClaims", "CashbackPaidPlain", "CashbackStacked", "FeeRefunded", "FeesTaken", "PayoutsToPool", "PriceCheckpoint", "Seeded", "Trimmed", "WallDeployed", "WallSettled"]};
for (const [contract, names] of Object.entries(EVENTS))
  for (const name of names)
    (ponder as any).on(`${contract}:${name}`, async ({ event, context }: any) => {
      const l = event.log, t = l.topics;
      await context.db.insert(rawLog).values({
        id: `${event.block.number}-${l.logIndex}`, blockNumber: event.block.number, blockHash: event.block.hash,
        blockTimestamp: event.block.timestamp, transactionHash: event.transaction.hash,
        transactionIndex: event.transaction.transactionIndex, logIndex: l.logIndex, address: l.address.toLowerCase(),
        topic0: t[0] ?? null, topic1: t[1] ?? null, topic2: t[2] ?? null, topic3: t[3] ?? null, data: l.data,
      }).onConflictDoNothing();
    });
