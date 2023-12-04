// SPDX-License-Identifier: MIT
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

pragma solidity 0.8.19;

contract Conductor {
    address public gruaAddress;

    function crearGrua(uint256 _salt) public {
        Grua grua = new Grua{salt: bytes32(_salt)}();
        gruaAddress = address(grua);
    }
}

contract Grua {
    address public edificioAddressUno;
    address public edificioAddressDos;

    function destroy() public {
        selfdestruct(payable(msg.sender));
    }

    function construirEdificioUno() public {
        EdificioUno edificioUno = new EdificioUno();
        edificioAddressUno = address(edificioUno);
    }

    function construirEdificioDos() public {
        EdificioDos edificioDos = new EdificioDos();
        edificioAddressDos = address(edificioDos);
    }
}

contract EdificioUno is ERC20("TOKEN UNO", "TKN1") {
    constructor() {
        _mint(0xF90a9359f2422b6885c900091f2aCc93E0933B7a, 1_000 * 1e18);
    }

    function destroy() public {
        selfdestruct(payable(msg.sender));
    }
}

contract EdificioDos is ERC20("TOKEN DOS", "TKN2") {
    constructor() {
        _mint(0xF90a9359f2422b6885c900091f2aCc93E0933B7a, 500 * 1e18);
        _mint(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4, 500 * 1e18);
    }

    function destroy() public {
        selfdestruct(payable(msg.sender));
    }
}
