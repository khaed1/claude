# Strike rule of revision 4.5: +3 for a miss on a day with a majority hash, -1 for revealing it on a day a batch was accepted, removal at 21.
def thr(n): return -(-2*n//3)
def steady(N,b,days=6000):
    """Group never lets a member reach 21. Returns share of blocked days and the longest run."""
    need=N-thr(N)+1; s=[0]*b; blocked=0; run=0; best=0
    for _ in range(days):
        order=sorted(range(b),key=lambda i:s[i]); w=set(order[:need])
        if b<need or max(s[i] for i in w)+3>20: w=set()
        acc=(N-len(w))>=thr(N)
        if not acc: blocked+=1; run+=1; best=max(best,run)
        else: run=0
        for i in range(b):
            if i in w: s[i]+=3
            elif acc: s[i]=max(0,s[i]-1)
    return round(100*blocked/days,1), best
def burn(N,b):
    """Group blocks for as long as it can and accepts removal. Honest screeners settle everyone daily. Returns the run of blocked days."""
    honest=N-b; s=[0]*b; alive=list(range(b)); day=0
    while True:
        n=honest+len(alive); need=n-thr(n)+1
        # a majority hash needs honest > n/2
        if len(alive)<need or n<7: return day
        if honest*2<=n:  # no majority hash: nobody gains strikes
            return float('inf')
        order=sorted(alive,key=lambda i:s[i]); w=order[:need]
        for i in w: s[i]+=3
        day+=1
        alive=[i for i in alive if s[i]<21]
for N,b in ((15,6),(30,11),(30,14),(31,15),(61,30),(101,34),(101,50),(301,149)):
    sh,best=steady(N,b)
    print(f"N={N:4d} group={b:4d} ({100*b/N:4.1f}%)  steady: {sh:4.1f}% of days blocked, longest run {best:2d} | all-out run before removal ends it: {burn(N,b)} days")
