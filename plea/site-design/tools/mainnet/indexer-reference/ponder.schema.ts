import { onchainTable } from "ponder";
export const rawLog = onchainTable("raw_log", (t) => ({
  id: t.text().primaryKey(),
  blockNumber: t.bigint().notNull(),
  blockHash: t.hex().notNull(),
  blockTimestamp: t.bigint().notNull(),
  transactionHash: t.hex().notNull(),
  transactionIndex: t.integer().notNull(),
  logIndex: t.integer().notNull(),
  address: t.hex().notNull(),
  topic0: t.hex(),
  topic1: t.hex(),
  topic2: t.hex(),
  topic3: t.hex(),
  data: t.hex().notNull(),
}));
