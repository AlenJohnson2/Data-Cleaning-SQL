-- Firstly,I imported the dataset into a new database using import flat file option. 
-- Then I checked for anomalies in the dataset for the cleaning process.

use housing;
select * from nashville;

-- 1) Standardize date format

update nashville 
set SaleDate = convert(date, SaleDate);

-- 2) Populate Property address data (null)

select * from nashville
where propertyaddress is null;

-- If the parcel id of the null row in property address is present in another row with property address, it is highly likely that both those addresses are the same.
-- So I am going to populate the null rows with the addresses from the rows with the same parcel ID.

select na.parcelid,na1.parcelid,na.propertyaddress,na1.propertyaddress, isnull(na.propertyaddress, na1.PropertyAddress)
from nashville na 
join nashville na1 on na.parcelid = na1.parcelID  -- we want same parcel id but different unique id so that we wont get the same row.
and na.uniqueid <> na1.uniqueid
where na.propertyaddress is null;

update na
set	propertyaddress = isnull(na.propertyaddress, na1.PropertyAddress)
from nashville na 
join nashville na1 on na.parcelid = na1.parcelID  
and na.uniqueid <> na1.uniqueid
where na.propertyaddress is null;

-- Breaking out the address into individual columns (Address,City,State)
-- Use -1 and +1 to get rid of the ','

select substring(propertyaddress,1,charindex(',',propertyaddress)-1) Address,
substring(propertyaddress,charindex(',',propertyaddress)+1, len(propertyaddress))City
from nashville;

alter table nashville
add PropertysplitAddress nvarchar(255);
alter table nashville
add PropertyCity nvarchar(255);

update nashville
set PropertysplitAddress  = substring(propertyaddress,1,charindex(',',propertyaddress)-1);
update nashville
set PropertyCity  = substring(propertyaddress,charindex(',',propertyaddress)+1,len(propertyaddress));

-- State name from owner address
-- Parse name only looks for '.'.  And it works backwards in the string(so 1 is from the back). Easier to work than substring.

select parsename(replace(owneraddress,',','.'),3),parsename(replace(owneraddress,',','.'),2), parsename(replace(owneraddress,',','.'),1)
from nashville;

alter table nashville
add OwnersplitAddress nvarchar(255);
alter table nashville
add OwnerCity nvarchar(255);
alter table nashville
add OwnerState nvarchar(255);

update nashville
set OwnersplitAddress = parsename(replace(owneraddress,',','.'),3);
update nashville
set OwnerCity = parsename(replace(owneraddress,',','.'),2);
update nashville
set OwnerState = parsename(replace(owneraddress,',','.'),1);

-- 3) Change values of SoldAsVacant column from 0 and 1 to Yes and No.

select case when soldasvacant = 0 then 'NO' 
when soldasvacant = 1 then'YES' else cast(SoldAsVacant as varchar(3)) end , SoldAsVacant
from nashville;

-- Change the data type of the column from int to varchar.
alter table nashville
alter column SoldAsVacant varchar(3);

update nashville
	set SoldAsVacant = case when soldasvacant = 0 then 'NO' 
	when soldasvacant = 1 then'YES' else cast(SoldAsVacant as varchar(3)) end ;
	
-- 4) Remove Duplicates

with row_cte as 
(select *, ROW_NUMBER() over (partition by ParcelID, PropertyAddress, SalePrice, Saledate, LegalReference order by uniqueid)row_num
from nashville)

-- If there are same values for rows in these columns, we can assume that row is a duplicate. 
-- To identify duplicate rows, we should exclude columns that make a row unique. So include all columns excluding those that make a row unique.
-- We can't use UniqueID as it is unique for each row irrespective of duplicates in the other columns.

delete from row_cte
where row_num > 1 

-- 5) Delete unused columns

alter table nashville
drop column PropertyAddress, OwnerAddress, TaxDistrict;

select * from nashville;


