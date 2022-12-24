https://github.com/ShipyardDAO/student.vinceferro/tree/784d11eb4285bab275b18a4e51355c2c99445834/dao

The following is a micro audit by Alex.S

# General Comments

An excellent submission. I really can't find anything to fault. The code is clear and everything appears to be covered. It's probably the best answer to this exercise that I've seen.


# Design Exercise

An interesting and well thought out answer. I think that vote delegation can be done in a reasonably efficient manner, whereby one transaction is needed for someone to delegate their vote and one transaction is needed for someone to cast their vote (and if 20 other people have already delegated to them, either directly or transitively, this counts as 21 votes). One problem that needs to be thought about with transitive voting is the possibility of cycles (A delegates to B, who delegates to C, who delegates to A).


# Score

| Reason | Score |
|-|-|
| Late                       | - |
| Unfinished features        | - |
| Extra features             | - |
| Vulnerability              | - |
| Unanswered design exercise | - |
| Insufficient tests         | - |
| Technical mistake          | - |

Total: 0

Great job!
