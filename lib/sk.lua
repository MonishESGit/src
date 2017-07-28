-- # Scott Knott test
-- 
-- Recursive bi-clustering of  set of `samples`.
-- Before desceding into either split, pause and check
-- if the splits are statistically different.
-- Returns the samples, sorted on their median, labelled
-- with a `rank` number. If two adjecent samples are
-- statistically the same, then they get the same rank.
-- If all samples get ranked "1" then that means there
-- are no interesting distinctions between these samples.

require "show"
local the=require "config"
local tiles=require "tiles"

---------------------------------
-- Simple utils
local function nth(t,n) return t._all[ math.floor(#t._all*n) ] end
local function mid(t)   return nth(t,0.5) end
local function iqr(t)   return nth(t,0.75) - nth(t,0.25) end
---------------------------------
-- Here's a simple counter, used to track  `mu` and `all`.

local function create() return {
  _all={}, sum=0,n=0, mu=0} end

-- Here how to update a counter with one value `x`.
local function update(i,x) 
  i._all[#i._all+1]=x
  i.sum = i.sum + x
  i.n   = i.n + 1 
  i.mu  = i.sum/i.n end

-- Here how to update a counter with many values from `t`.
local function updates(t, counter)
  counter = counter or create()
  for j=1,#t do 
    update(counter,t[j]) end end
---------------------------------------------
-- This code is always counting left and right within
-- the list of samples. To save time, memo all those 
-- "peeks".
local function memo(samples,here,stop,_memo,    b4,inc)
  if stop > here then inc=1 else inc=-1 end
  if here ~= stop then 
     b4=  lst.copy( memo(samples,here+inc, stop, _memo)) end
  _memo[here] = updates(samples[here]._all,  b4)
  return _memo[here] end
---------------------------------------------
-- Seek a split that maximizes the expected value
-- of the square of the difference in means before
-- and after the split. At that point, if the two
-- splits are not statistically the same, then
-- recurse into each part of the split.
return function (samples,epsilon,same)
  epsilon = epsilon or the.sample.epsilon
  local function split(lo,hi,all,rank,lvl)   
    local best,lmemo,rmemo = 0,{},{}
    memo(samples,hi,lo, lmemo) -- summarize i+1 using i
    memo(samples,lo,hi, rmemo) -- summarize i using i+1
    local cut, lbest, rbest
    -- step1: look for the best cut
    for j=lo,hi-1 do
      local l = lmemo[j]
      local r = rmemo[j+1]
      if mid(l)*epsilon   < mid(r) then
        if not same(l,r) then
          local tmp= l.n/all.n*(l.mu - all.mu)^2 + 
                     r.n/all.n*(r.mu - all.mu^2)
          if tmp > best then
            cut   = j
            best  = tmp
            lbest = lst.copy(l)
            rbest = lst.copy(r) end end end end
    -- step2a: use the cut (if you found it)
    if cut then
      rank = split(lo,   cut, lbest, rank, lvl+1) + 1
      rank = split(cut+1, hi, rbest, rank, lvl+1)
    else
    -- step2b: otherwise, all samples get same rank
      for j=lo,hi do
        samples[j].rank = rank end end
    return rank 
  end 
  -- Main
  table.sort(samples, function (x,y) return 
             mid(x) < mid(y) end)
  split(1,#samples, memo(samples,1,#samples,{}),1,0)  
  return samples end
