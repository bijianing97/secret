pragma solidity >=0.4.22 <0.6.0;
//只编写了秘密结构体
//美文需要补充
// 定义三种结构体，1、秘密（包括公开秘密和可交换秘密），2、需支付购买的秘密
// 3、对需支付购买的秘密和可交换的秘密的描述

// 维护变量有：

// 结构体数组：
// 1、公开的秘密
// 2、可支付的秘密
// 3、可交换的秘密
// 4、描述
// 映射：
// 1、某个用户对应发布的所有公开秘密
// 2、某个用户对应发布的所有可支付秘密
// 3、某个用户对应发布的所有可交换秘密
// 4、某个用户对应某个秘密是否有查看的资格（通过用户地址和秘密类型和秘密在数组中的索引构造出唯一
//    的bytes值计算哈希后的bytes值，来映射到一个bool变量，该变量表示用户是否有资格查看某个秘密）
// 5、某个用户对应某个秘密是否已经点赞过了（同理）
// 6、某个用户通过购买获得的所有秘密
// 7、某个用户通过交换秘密获得的所有秘密
contract simpleSecretShare{
    address contractOwner;

    enum SecretType{
        free,
        exchangable,
        Payable
    }

    struct Secret{
        uint createTime;
        uint8 stars;
        SecretType SecretsType;
        address secretOwner;
        string content;
    }

    struct PayableSecret{
        uint createTime;
        uint8 price;
        uint8 stars;
        address secretOwner;
        string content;
    }

    struct Description{
        string discription;
        uint index;
        // address owner;
        SecretType SecretsType;
    }

    Secret[] public publicSecrets;
    Secret[] private exchangableSecrets;
    PayableSecret[] private payableSecrets;
    Description[] public  descs;
    mapping(address => uint[]) private ownerToPayableSecrets;
    mapping(address => uint[]) private ownerToExchangableSecrets;
    mapping(address => uint[]) public  ownerToPublicSecrets;
    mapping(bytes32 => bool) private hasViewRight;
    mapping(bytes32 => bool) private hasLike;
    mapping(address => uint[]) private haveBuyPayableSecrets;
    mapping(address => uint[]) private haveExchangeSecrets;


    constructor()public {
        contractOwner = msg.sender;
    }

    function toString(address x,uint index,SecretType Type)private pure returns (bytes memory) {
        bytes memory b = new bytes(53);
        for (uint i = 0; i < 20; i++)
            b[i] = byte(uint8(uint(x) / (2**(8*(19 - i)))));
        for (uint i = 0; i < 32; i++)
            b[i+20] = byte(uint8(uint(index) / (2**(8*(31 - i)))));
        if(Type == SecretType.Payable)
            b[52] = 0x00;
        else if(Type == SecretType.free)
            b[52] = 0x0f;
        else
            b[52] = 0xff;
        return b;
    }

    // 通过用户地址和秘密类型和秘密在数组中的索引构造出唯一的bytes值,返回计算哈希后的bytes值
    function getMixbytesHash(address addr, uint index, SecretType Type)private pure returns(bytes32)  {
        bytes memory mixbytes = toString(addr,index,Type);
        return keccak256(mixbytes);
    }

    // 判断拥有对某个需购买的或者是可交换的秘密是否有查看的权力
    modifier hasNotViewRightTo(address addr,uint index,SecretType Type){
        if(Type == SecretType.Payable)
        require(!hasViewRight[getMixbytesHash(addr,index,Type)]&&
            payableSecrets[index].secretOwner != addr);
        else
        require(!hasViewRight[getMixbytesHash(addr,index,Type)]&&
            exchangableSecrets[index].secretOwner != addr);
        _;
    }

    // 判断用户对某个需购买的或者是可交换的秘密是否有查看的权力
    modifier hasViewRightTo(address addr,uint index,SecretType Type){
        if(Type == SecretType.Payable)
        require(hasViewRight[getMixbytesHash(addr,index,Type)]||
            payableSecrets[index].secretOwner == addr);
        else
        require(hasViewRight[getMixbytesHash(addr,index,Type)]||
            exchangableSecrets[index].secretOwner == addr);
        _;
    }

    // 赋予用户对某个需购买的或者是可交换的秘密可以查看的权力
    function entitleTo(address addr, uint index,SecretType Type)private{
        bytes32  mixbytesVlue;
        if(Type == SecretType.Payable){
            mixbytesVlue = getMixbytesHash(addr,index,Type);
            haveBuyPayableSecrets[addr].push(index);
        }else{
            mixbytesVlue = getMixbytesHash(addr,index,Type);
            haveExchangeSecrets[addr].push(index);
        }
        hasViewRight[mixbytesVlue] = true;
    }

    // 查看用户所有已经购买的秘密
    function getHaveBuyPayableSecrets()public view returns(uint[] memory){
        return haveBuyPayableSecrets[msg.sender];
    }

    // 查看用户所有已经交换获得的秘密
    function getHaveExchangeSecrets()public view returns(uint[] memory){
        return haveExchangeSecrets[msg.sender];
    }

    // 查看用户所有自己发布的需要购买获得的秘密
    function getOwnerPayableSecrets()public view returns(uint[] memory){
        return ownerToPayableSecrets[msg.sender];
    }

    // 查看用户所有自己发布的需要交换获得的秘密
    function getOwnerExchangableSecrets()public view returns(uint[] memory){
        return ownerToExchangableSecrets[msg.sender];
    }

    // 获得某个需要购买的秘密
    function getAPayableSecret(uint index)public view hasViewRightTo(msg.sender,index,SecretType.Payable)
    returns(uint, string memory, uint8, uint8,address){
        PayableSecret storage theSecret = payableSecrets[index];
        return (theSecret.createTime,theSecret.content,theSecret.price,theSecret.stars,theSecret.secretOwner);
    }

    // 获得某个需要交换的秘密
    function getAExchangableSecret(uint _index)public view hasViewRightTo(msg.sender,_index,SecretType.exchangable)
    returns(uint, string memory,uint8,address){
        Secret storage theSecret = exchangableSecrets[_index];
        return (theSecret.createTime,theSecret.content,theSecret.stars,theSecret.secretOwner);
    }

    // 发布一个秘密
    function postASecret(uint8 uintSecretType,string memory content,string memory desc,uint8 price)public{
        uint Index;
        require(uintSecretType<3);
        if(uintSecretType == 0){
            Index = publicSecrets.push(Secret({stars:0,
                                      createTime:now,
                                      content:content,
                                      SecretsType:SecretType.free,
                                      secretOwner:msg.sender
            }));
            ownerToPublicSecrets[msg.sender].push(Index);
        }else if(uintSecretType == 1){
            Index = exchangableSecrets.push(Secret({stars:0,
                                      createTime:now,
                                      content:content,
                                      SecretsType:SecretType.exchangable,
                                      secretOwner:msg.sender
            }));
            descs.push(Description({discription : desc,
                                index : Index,
                                // owner : msg.sender,
                                SecretsType : SecretType.exchangable
            }));
            ownerToExchangableSecrets[msg.sender].push(Index);
        }else if(uintSecretType == 2){
            require(price > 0,"the price should be p-ositive");
            Index = payableSecrets.push(PayableSecret({stars:0,
                                      createTime:now,
                                      content:content,
                                      price:price,
                                      secretOwner:msg.sender
            }));
            descs.push(Description({discription : desc,
                                    index : Index,
                                    // owner : msg.sender,
                                    SecretsType : SecretType.Payable
            }));
            ownerToPayableSecrets[msg.sender].push(Index);
        }else{}
    }

    // 购买某个需要需购买获得的秘密
    function purchasePayableSecret(uint index) hasNotViewRightTo(msg.sender,index,SecretType.Payable) payable public{
        require(msg.value == payableSecrets[index].price,'have not enough cost');
        entitleTo(msg.sender,index,SecretType.Payable);
    }

    // 交换某个需要需交换获得的秘密
    function  exchangeSecret(uint targetSecret, uint ownerSecret)public hasNotViewRightTo(msg.sender,targetSecret,SecretType.exchangable)
    hasNotViewRightTo(exchangableSecrets[targetSecret].secretOwner,targetSecret,SecretType.exchangable){
        require(exchangableSecrets[ownerSecret].secretOwner==msg.sender,'it is not your own secret for exchange');
        require(exchangableSecrets[targetSecret].stars<=exchangableSecrets[ownerSecret].stars,'only more stars secret can be exchanged');
        entitleTo(msg.sender,targetSecret,SecretType.exchangable);
        entitleTo(exchangableSecrets[targetSecret].secretOwner,ownerSecret,SecretType.exchangable);
    }

    // 用户点赞某个秘密
    function like(uint index,uint8 uintSecretType)public{
        require(uintSecretType<3);
        SecretType Type;
        if(uintSecretType == 0) Type = SecretType.free;
        else if (uintSecretType ==1) Type = SecretType.exchangable;
        else if (uintSecretType ==2) Type = SecretType.Payable;
        else{}
        bytes32 MixbytesHash = getMixbytesHash(msg.sender, index, Type);
        require(!hasLike[MixbytesHash],"you can not like this secret twice");
        hasLike[MixbytesHash] = true;
    }


}
