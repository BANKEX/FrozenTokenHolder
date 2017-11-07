# BankEx Token Freezer Contract

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

