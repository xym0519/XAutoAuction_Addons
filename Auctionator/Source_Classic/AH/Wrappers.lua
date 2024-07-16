-- query = {
--   searchString -> string
--   minLevel -> int?
--   maxLevel -> int?
--   itemClassFilters -> itemClassFilter[]
--   isExact -> boolean?
-- }
function Auctionator.AH.QueryAuctionItems(query)
  Auctionator.AH.Internals.scan:StartQuery(query, 0, -1)
end

function Auctionator.AH.QueryAndFocusPage(query, page)
  Auctionator.AH.Internals.scan:StartQuery(query, page, page)
end

function Auctionator.AH.GetCurrentPage()
  return Auctionator.AH.Internals.scan:GetCurrentPage()
end

function Auctionator.AH.AbortQuery()
  Auctionator.AH.Internals.scan:AbortQuery()
end

-- Event ThrottleUpdate will fire whenever the state changes
function Auctionator.AH.IsNotThrottled()
  return Auctionator.AH.Internals.throttling:IsReady()
end

function Auctionator.AH.GetAuctionItemSubClasses(classID)
  return { GetAuctionItemSubClasses(classID) }
end

function Auctionator.AH.PlaceAuctionBid(...)
  Auctionator.AH.Internals.throttling:BidPlaced()

  local index = select(1, ...)
  local stackPrice = select(2, ...)

  local buyTime = time();

  local itemName, _, stackCount, _, _, _, _, _, _, buyoutPrice = GetAuctionItemInfo('list', 1)
  local key = itemName .. ":" .. time() .. ":" .. #XAuctionatorBuyList + 1;
  local buyHistory = { itemName = itemName, buyTime = buyTime, price = buyoutPrice / stackCount, count = stackCount };
  XAuctionatorBuyList[key] = buyHistory;

  PlaceAuctionBid("list", index, stackPrice)
end

function Auctionator.AH.PostAuction(...)
  Auctionator.AH.Internals.throttling:AuctionsPosted()

  local startingBid = select(1, ...)
  local buyoutPrice = select(2, ...)
  local duration = select(3, ...)
  local stackSize = select(4, ...)
  local numStacks = select(5, ...)
  local itemInfo = select(6, ...)

  local sellTime = time();

  local key = itemInfo.itemName .. ":" .. time();
  local sellHistory = {
    itemName = itemInfo.itemName,
    sellTime = sellTime,
    price = buyoutPrice / stackSize,
    count = stackSize * numStacks,
    stackPrice = buyoutPrice,
    stackSize = stackSize,
    stackCount = numStacks
  };
  XAuctionatorSellList[key] = sellHistory;

  PostAuction(startingBid, buyoutPrice, duration, stackSize, numStacks)
end

-- view is a string and must be "list", "owner" or "bidder"
function Auctionator.AH.DumpAuctions(view)
  local auctions = {}
  for index = 1, GetNumAuctionItems(view) do
    local auctionInfo = { GetAuctionItemInfo(view, index) }
    local itemLink = GetAuctionItemLink(view, index)
    local timeLeft = GetAuctionItemTimeLeft(view, index)
    local entry = {
      info = auctionInfo,
      itemLink = itemLink,
      timeLeft = timeLeft - 1, --Offset to match Retail time parameters
      index = index,
    }
    table.insert(auctions, entry)

    local itemName = auctionInfo[1]
    local stackCount = auctionInfo[3]
    local buyoutPrice = auctionInfo[10]
    local time = time()
    local key = itemName .. ":" .. (time - time % 60);
    if (not XAuctionatorScanList[key]) then
      local item = {
        itemName = itemName,
        maxPrice = buyoutPrice / stackCount,
        minPrice = buyoutPrice / stackCount,
        sumPrice = buyoutPrice,
        count = stackCount
      };
      XAuctionatorScanList[key] = item;
    else
      local item = XAuctionatorScanList[key];
      if (item.maxPrice < buyoutPrice / stackCount) then
        item.maxPrice = buyoutPrice / stackCount;
      end
      if (item.minPrice > buyoutPrice / stackCount) then
        item.minPrice = buyoutPrice / stackCount;
      end
      item.sumPrice = item.sumPrice + buyoutPrice;
      item.count = item.count + stackCount;
      XAuctionatorScanList[key] = item;
    end
  end
  return auctions
end

function Auctionator.AH.CancelAuction(auction)
  for index = 1, GetNumAuctionItems("owner") do
    local info = { GetAuctionItemInfo("owner", index) }

    local stackPrice = info[Auctionator.Constants.AuctionItemInfo.Buyout]
    local stackSize = info[Auctionator.Constants.AuctionItemInfo.Quantity]
    local bidAmount = info[Auctionator.Constants.AuctionItemInfo.BidAmount]
    local saleStatus = info[Auctionator.Constants.AuctionItemInfo.SaleStatus]
    local itemLink = GetAuctionItemLink("owner", index)

    if saleStatus ~= 1 and auction.bidAmount == bidAmount and auction.stackPrice == stackPrice and auction.stackSize == stackSize and Auctionator.Search.GetCleanItemLink(itemLink) == Auctionator.Search.GetCleanItemLink(auction.itemLink) then
      Auctionator.AH.Internals.throttling:AuctionCancelled()
      CancelAuction(index)
      break
    end
  end
end
