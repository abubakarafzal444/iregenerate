import ethers from "ethers";

const MOCK_START = [
  { value: 1, time: 1662616906 },
  { value: 2, time: 1662619148 },
  { value: 1, time: 1662621627 },
  { value: 1, time: 1662622604 },
  { value: 1, time: 1662972608 },
  { value: 2, time: 1662973194 },
  { value: 1, time: 1662974576 },
  { value: 1, time: 1662975479 },
  { value: 1, time: 1662975554 },
  { value: 2, time: 1662975690 },
  { value: 3, time: 1662978979 },
  { value: 3, time: 1662979789 },
  { value: 1, time: 1662981186 },
  { value: 9, time: 1662981638 },
  { value: 1, time: 1662983935 },
  { value: 10, time: 1662984072 },
  { value: 1, time: 1663036638 },
  { value: 1, time: 1663036863 },
  { value: 1, time: 1663036983 },
  { value: 1, time: 1663040617 },
  { value: 1, time: 1663041247 },
  { value: 1, time: 1663119981 },
  { value: 2, time: 1663124529 },
  { value: 1, time: 1663125519 },
  { value: 2, time: 1663146111 },
  { value: 2, time: 1663206389 },
  { value: 2, time: 1663208367 },
  { value: 3, time: 1663208682 },
  { value: 1, time: 1663208967 },
  { value: 1, time: 1663209027 },
  { value: 2, time: 1663210498 },
  { value: 7, time: 1663211414 },
  { value: 1, time: 1663212179 },
  { value: 3, time: 1663297601 },
  { value: 2, time: 1663298606 },
  { value: 5, time: 1663302735 },
  { value: 2, time: 1663306880 },
  { value: 2, time: 1663573340 },
];
const MOCK_END = [
  { value: 1, time: 1662618593 },
  { value: 2, time: 1662620425 },
  { value: 1, time: 1662621912 },
  { value: 1, time: 1662623489 },
  { value: 1, time: 1662972773 },
  { value: 3, time: 1662975044 },
  { value: 1, time: 1662976531 },
  { value: 3, time: 1662979654 },
  { value: 3, time: 1662979744 },
  { value: 3, time: 1662980570 },
  { value: 10, time: 1662983875 },
  { value: 1, time: 1662984388 },
  { value: 10, time: 1662984658 },
  { value: 2, time: 1663037013 },
  { value: 2, time: 1663041127 },
  { value: 3, time: 1663124619 },
  { value: 3, time: 1663146231 },
  { value: 3, time: 1663206765 },
  { value: 1, time: 1663208742 },
  { value: 1, time: 1663209177 },
  { value: 7, time: 1663211339 },
  { value: 7, time: 1663211579 },
  { value: 1, time: 1663212900 },
  { value: 1, time: 1663297856 },
  { value: 3, time: 1663300107 },
  { value: 1, time: 1663300512 },
  { value: 5, time: 1663302780 },
  { value: 1, time: 1663306925 },
  { value: 1, time: 1663573331 },
];
const MOCK_RECYCLE_STAKING_RECORDS = [
  { start: 1662616900, end: 1662616906 },
  { start: 1662972000, end: 1662972773 },
  { start: 1662973100, end: 1662975029 },
  { start: 1663573331, end: 1663573340 },
];
const MOCK_RE_STAKING_RECORDS = [
  { start: 1662616906, end: 1662618593 },
  { start: 1662619148, end: 1662620425 },
  { start: 1662621627, end: 1662621912 },
  { start: 1662622604, end: 1662623489 },
  { start: 1662972608, end: 1662972773 },
  { start: 1662973194, end: 1662975044 },
  { start: 1662975479, end: 1662976531 },
  { start: 1662975554, end: 1662979654 },
  { start: 1662978979, end: 1662979744 },
  { start: 1662979789, end: 1662980570 },
  { start: 1662981186, end: 1662983875 },
  { start: 1662983935, end: 1662984388 },
  { start: 1662984072, end: 1662984658 },
  { start: 1663036638, end: 1663037013 },
  { start: 1663036983, end: 1663041127 },
  { start: 1663041247, end: 1663206765 },
  { start: 1663208367, end: 1663209177 },
  { start: 1663208682, end: 1663211339 },
  { start: 1663211414, end: 1663211579 },
  { start: 1663212179, end: 1663212900 },
  { start: 1663297601, end: 1663300512 },
  { start: 1663302735, end: 1663302780 },
  { start: 1663306880, end: 1663573331 },
];

const sortReStakingDuration = (start, end) => {
  let stakingRecords = [];

  let startTime = 0;
  let endTime = 0;

  let leftStakeAmount = 0;
  let leftUnstakeAmount = 0;

  let currStartIndex = 0;
  let record;

  for (let i = 0; i < end.length; i++) {
    if (leftUnstakeAmount < 0 || start[currStartIndex].value < end[i].value) {
      // stake many times but unstake once
      for (let j = currStartIndex; j < start.length; j++) {
        if (startTime == 0 && leftUnstakeAmount == 0) {
          leftUnstakeAmount = end[i].value;
          startTime = start[currStartIndex].time;
        } else if (leftUnstakeAmount < 0) {
          leftUnstakeAmount += end[i].value;
        }

        leftUnstakeAmount -= start[j].value;

        if (leftUnstakeAmount < 0) {
          currStartIndex = ++j;
          break;
        } else if (leftUnstakeAmount == 0) {
          endTime = end[i].time;
          currStartIndex = ++j;
          break;
        }

        currStartIndex++;
      }
    } else if (
      leftStakeAmount !== 0 ||
      start[currStartIndex].value > end[i].value
    ) {
      // stake once but unstake many times
      if (startTime == 0 && leftStakeAmount == 0) {
        leftStakeAmount = start[currStartIndex].value;
        startTime = start[currStartIndex].time;
      } else if (leftStakeAmount < 0) {
        leftStakeAmount += start[currStartIndex].value;
      }

      leftStakeAmount -= end[i].value;

      if (leftStakeAmount < 0) {
        currStartIndex++;
        continue;
      } else if (leftStakeAmount == 0) {
        endTime = end[i].time;
        currStartIndex++;
      }
    } else if (start[currStartIndex].value === end[i].value) {
      //   stake once unstake once
      record = {
        start: new Date(start[currStartIndex].time * 1000),
        end: new Date(end[i].time * 1000),
      };
      stakingRecords.push(record);
      currStartIndex++;
      continue;
    }

    if (startTime > 0 && endTime > 0) {
      record = {
        start: new Date(startTime * 1000),
        end: new Date(endTime * 1000),
      };
      stakingRecords.push(record);
      startTime = 0;
      endTime = 0;
    }

    if (i === end.length - 1 && start[currStartIndex].time > end[i].time) {
      // last stake one not unstake yet
      stakingRecords.push({
        start: new Date(start[currStartIndex].time * 1000),
        end: 0,
      });
    }
  }

  if (stakingRecords.length === 0) {
    // only stake once
    stakingRecords.push({
      start: start[0].time,
      end: 0,
    });
  }

  return stakingRecords;
};

const calculateHighYieldDuration = (
  recycleStakingRecords,
  reStakingRecords
) => {
  let highYieldSecs = 0;

  recycleStakingRecords.forEach((record) => {
    for (let i = 0; i < reStakingRecords.length; i++) {
      // first Re staking starting time is behind first Recycle staking record
      // then followings are behind as well, break the loop
      if (reStakingRecords[i].start >= record.end) break;
      // this RE staking ending time is prior to Recycle staking period
      // not calculate high yield seconds
      if (reStakingRecords[i].end <= record.start) continue;
      let start =
        reStakingRecords[i].start <= record.start
          ? record.start
          : reStakingRecords[i].start;
      let end =
        reStakingRecords[i].end > 0
          ? reStakingRecords[i].end <= record.end
            ? reStakingRecords[i].end
            : record.end
          : record.end;
      let duration = end - start;
      highYieldSecs += duration;
    }
  });

  return highYieldSecs;
};

console.log("Sort RE Staking Durations", sortReStakingDuration(MOCK_START, MOCK_END));
console.log("High Yield Seconds:", calculateHighYieldDuration(
    MOCK_RECYCLE_STAKING_RECORDS,
    MOCK_RE_STAKING_RECORDS
  )
);

// const RE_NFT_CONTRACT = "0xf68ca8d035d3cadd26ad6217b2bbbc90bf096979";
// const RE_STAKE_CONTRACT = "0x7dabfb9b6de663a83aa3e6639813855a9dd853c1";
// const I_ABI = [
//   "event Transfer(address indexed from, address indexed to, uint256 indexed tokenId)",
//   "event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value)",
// ];

// const provider = ethers.getDefaultProvider("rinkeby");
// const reNFT = new ethers.Contract(RE_NFT_CONTRACT, I_ABI, provider);

// const reStakeFilter = reNFT.filters.TransferSingle(
//   null,
//   "0xBD25331f1EEfbE22075F3ed8a37D3254423E1b7b",
//   RE_STAKE_CONTRACT,
//   null,
//   null
// );
// const reUnstakeFilter = reNFT.filters.TransferSingle(
//   null,
//   RE_STAKE_CONTRACT,
//   "0x666611beB1d97A2A96B73B5e25e332afBd12266d",
//   null,
//   null
// );

// const reStakeQuery = await reNFT.queryFilter(reStakeFilter);
// const reStakeResult = reStakeQuery.filter(
//   (result) => result.args.id.toNumber() === 1
// );
// const reStartStake = await Promise.all(
//   reStakeResult.map(async (result) => {
//     let block = await result.getBlock();
//     let item = {
//       value: result.args.value.toNumber(),
//       time: block.timestamp,
//     };
//     return item;
//   })
// );

// const reUnstakeQuery = await reNFT.queryFilter(reUnstakeFilter);
// const reUnstakeResult = reUnstakeQuery.filter(
//   (result) => result.args.id.toNumber() === 1
// );
// const reEndStake = await Promise.all(
//   reUnstakeResult.map(async (result) => {
//     let block = await result.getBlock();
//     let item = {
//       value: result.args.value.toNumber(),
//       time: block.timestamp,
//     };
//     return item;
//   })
// );

// console.log(reStartStake);
// console.log(reEndStake.length);

// ====================================================================================

const RECYCLE_NFT_CONTRACT = "";
const RECYCLE_STAKE_CONTRACT = "";

// const recycleNFT = new ethers.Contract(RECYCLE_NFT_CONTRACT, I_ABI, provider);

// const recycleStakeFilter = recycleNFT.filters.Transfer(
//     "0xBD25331f1EEfbE22075F3ed8a37D3254423E1b7b", RECYCLE_STAKE_CONTRACT, null);
// const recycleUnstakeFilter = recycleNFT.filters.Transfer(
//     RECYCLE_STAKE_CONTRACT, "0xBD25331f1EEfbE22075F3ed8a37D3254423E1b7b", null);

// const recycleStakeQuery = await recycleNFT.queryFilter(recycleStakeFilter);
// const recycleUnstakeQuery = await recycleNFT.queryFilter(recycleUnstakeFilter);
