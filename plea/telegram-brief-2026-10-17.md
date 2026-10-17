hey guys, quick update on PLEA

what it is: a meme token on uniswap v4 where buying is open but selling needs a plea. you write why you want to sell, and the Cabal (an IMD oracle panel, 30 judges) scores it 0-45. your score has to reach a need the contract works out from on-chain facts: how much of your bag you're selling, how long you held, your profit or loss, and the 24h trend. approved = you sell within 7 minutes. denied = one appeal. and if the Cabal goes 33 hours without a verdict it dies, and PLEA trades free forever.

what's built:
- the token, the v4 hook (fees, a buy wall, and a cap that burns what gets sold back above it), the gate, letters (write a letter and it sells for you if approved), Objection! (anyone can challenge an approval and a fresh panel re-scores it), and seasons where the best pleaders split a prize pot
- 0.5% of every trade goes back to the trader as staked IMD through imd/acc
- seat holders get 1.2x season points, and 10% of the supply goes to the swarm
- built with the swarm the whole way: 8 audit rounds plus a launch job on every version, every critical, high and medium fixed, 847 tests
- 7 launches live on sepolia. run 7 (launch #1843) lived its whole life there: launch, 33h of Cabal, death, free market. everything that doesn't need a verdict worked
- 10 real mainnet panels scored our exact plea texts, that's how we set the numbers

where we are: the code is ready for mainnet (14,000 IMD opening market cap). the last thing to test live is the verdict path, and that's waiting on sepolia oracle answers coming back. run 8.5 (launch #1981) has the final code deployed on sepolia, ready for it. after that, the mainnet launch job.

code: github.com/khaed1/plea
