# BankEx Token Freezer Contract

## Inside

In the "contracts" folder there is a  FrozenTokenHolder.sol, the token holder contract (balance of corresponding address on a main token contract for this holder is >0). Holder keeps balances for external addresses in form of tranches with the following parameters:
balance
fronzenAt
freezeTime (365 days as a default)
frozen - is tranche frozen or not for use

Holder has the following functions:

updateBalanceFromParent() - Syncs balance to main token. If 12 mil tokens need to be distributed, and there were only 10 mils initially (on the moment of creation), extra 2 mils can be added on main token contract and balance should be synced.

purchaseFor(address _for, uint256 _value, bool _unfrozen) - distribute tokens from reserve. Only "owner" can do it.

setDestination(address _dest, bool _allowed) - Set addresses that can receive tokens before unfreeze. Only "owner" can do it.

function balanceStructureIndexes(address _for) public view returns (uint256[] indexes) - set of tranche indexes for "_for"

function checkBalanceStructure(address _for, uint256 _index)  public view 
    returns (uint256 bal, uint256 frAt, uint256 frTime, bool fr) - returns tranche structure for the user and index. 
    bal - balance in tranche
    ftAt - freeze period start
    frTime - freeze period duration
    fr - is frozen or not


There is a set of ERC20-like functions with the same functionality

function transfer(address _to, uint256 _value) public returns (bool)
function transferFrom(address _from, address _to, uint256 _value) public returns (bool)
function approve(address _spender, uint256 _value) public returns (bool)
function allowance(address _owner, address _spender) view public returns (uint256 remaining)
function increaseApproval (address _spender, uint _addedValue) public returns (bool success) 
function decreaseApproval (address _spender, uint _subtractedValue) public returns (bool success) 


```bash
npm install
npm run test
```

tests.js tests the contract replicating the basic workflow

## В комплекте

В папке contracts находится FrozenTokenHolder.sol, контракт-держатель определенного количества токенов (соответственно, баланс адреса этого держателя в контракте токена будет не нулевым). Держатель ведет балансы для каждого отдельного внешнего адреса в виде траншей, каждый транш имеет параметры:
баланс
время заморозки
срок заморозки (по умолчанию 365 дней)
заморожен трашн или нет

 Держатель имеет следующий функционал:

updateBalanceFromParent() - синхронизирует максимально распределяемый баланс с балансом контракта-держателя в контракте-токене. 
Пример: изначально на держателе 10 миллионов токенов, а требуется распределить 12 миллионов. Можно добавить 2 миллиона на контракт в основной сети и затем распределить 12

purchaseFor(address _for, uint256 _value, bool _unfrozen) - распределение токенов из резерва. Доступно только владельцу (owner).

setDestination(address _dest, bool _allowed) - установить адрес, на который можно тратить токены до истечения времени разморозки.

function balanceStructureIndexes(address _for) public view returns (uint256[] indexes) - возвращает набор валидных индексов траншей для текущего пользователя.

function checkBalanceStructure(address _for, uint256 _index)  public view 
    returns (uint256 bal, uint256 frAt, uint256 frTime, bool fr) - возвращает структуру баланса для пользователя для определенного индекса. Поля 
    bal - баланс в транше
    ftAt - время начала заморозки (время создания транша)
    frTime - период заморозки
    fr - транз заморожен или нет


Стандартные ERC20 подобные функции соответствующие своим прототипам в стандарте ERC20

function transfer(address _to, uint256 _value) public returns (bool)
function transferFrom(address _from, address _to, uint256 _value) public returns (bool)
function approve(address _spender, uint256 _value) public returns (bool)
function allowance(address _owner, address _spender) view public returns (uint256 remaining)
function increaseApproval (address _spender, uint _addedValue) public returns (bool success) 
function decreaseApproval (address _spender, uint _subtractedValue) public returns (bool success) 


```bash
npm install
npm run test
```

После этого tests.js тестирует контракт, реплицируя время жизни контракта.


## Contributors

* [shamatar](https://github.com/shamatar)

