// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

library HeapSort {
    function sort(uint256[] memory arr)
        internal
        pure
        returns (uint256[] memory sortedArr)
    {
        uint256[] memory arr_ = arr;
        uint256 length = arr.length - 1;
        uint256 beginIndex = (arr.length >> 1) - 1;
        for (uint256 i = beginIndex; i >= 0; i--) {
            maxHeapify(arr_, i, length);
        }

        for (uint256 i = length; i > 0; i--) {
            maxHeapify(swap(arr_, 0, i), 0, i - 1);
        }
        return arr_;
    }

    function maxHeapify(
        uint256[] memory arr,
        uint256 index,
        uint256 length
    ) internal pure {
        uint256 leftIndex = (index << 1) + 1;
        uint256 rightIndex = (leftIndex + 1);
        uint256 cMax = leftIndex;
        if (leftIndex > length) return;
        if (rightIndex <= length && arr[rightIndex] > arr[leftIndex]) {
            cMax = rightIndex;
        }
        if (arr[cMax] > arr[index]) {
            maxHeapify(swap(arr, cMax, index), cMax, length);
        }
    }

    function swap(
        uint256[] memory arr,
        uint256 i,
        uint256 j
    ) internal pure returns (uint256[] memory swapArr) {
        uint256 temp = arr[i];
        arr[i] = arr[j];
        arr[j] = temp;
        return arr;
    }
}
