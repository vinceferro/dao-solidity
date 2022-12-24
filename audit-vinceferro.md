The following is a micro audit by Zvinodashe (Zed) Mupambirei
Discord : MatricksDeCoder#2974 

## **[L-1]** Save storage costs in struct

On line 54, defining the struct in CollectorDA0.sol. There is a 
```
uint256 voteEnd;
```
Consider: Removing this variable as where its used or checked it can always be calculated using voteBegin + VOTING_PERIOD;

## **[L-2]** Critical functionality lacks event

When a proposal is executed no event is emitted for such a critical activity. 

Inside functions on line 168 function execute or line 194 function _execute. 

Consider: Adding an event that is emitted when a proposal is executed in either of the functions.


## **[Q-1]** Test coverage 

Consider: adding more test cases focusing on edge cases, all functionality to ensure project works as expected and give confidence it works as expected.

**Notes**

- can't the address _expectedVoter in function _verifySig() be changed as its not part of message signed/ checks etc rendering members vote invalid?

