# Match usefulness checking

Lane2 semantic analysis checks match arm usefulness in addition to exhaustiveness. A match arm that cannot be selected because earlier arms already cover all of its values is rejected as unreachable or redundant, using the same pattern matrix model that supports exhaustiveness checking.
