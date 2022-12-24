// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library Checkpoints {
    struct Checkpoint {
        uint256 blockNumber;
        uint256 value;
    }

    struct History {
        Checkpoint[] _checkpoints;
    }

    /**
     * @dev Returns the value at a given block number. If a checkpoint is not available at that block, the closest one
     * before it is returned, or zero otherwise.
     */
    function getAtBlock(History storage self, uint256 blockNumber) internal view returns (uint256) {
        require(blockNumber < block.number, "E_BLOCK_NOT_MINED");

        uint256 high = self._checkpoints.length;
        uint256 low = 0;
        while (low < high) {
            uint256 mid = (low + high) / 2;
            if (self._checkpoints[mid].blockNumber > blockNumber) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }
        return high == 0 ? 0 : self._checkpoints[high - 1].value;
    }

    /**
     * @dev Pushes a value onto a History so that it is stored as the checkpoint for the current block.
     */
    function push(History storage self, uint256 value) internal {
        uint256 pos = self._checkpoints.length;
        if (pos > 0 && self._checkpoints[pos - 1].blockNumber == block.number) {
            self._checkpoints[pos - 1].value = value;
        } else {
            self._checkpoints.push(
                Checkpoint({blockNumber: block.number, value: value})
            );
        }
    }
}