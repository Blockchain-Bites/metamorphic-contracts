![Contratos Cambiantes El caso del Contrato Metamórfico](https://github.com/Blockchain-Bites/metamorphic-contracts/assets/3300958/4742f132-2a96-4999-a3bd-a4284a736725)

# <u>LOS CONTRATOS SÍ CAMBIAN DE CÓDIGO: CONTRATOS METAMÓRFICOS</u>

Los contratos inteligentes deberían entidades inmutables. Es decir, una vez que se publican, la lógica de dichos contratos no debería cambiar. Sin embargo, diferentes razones a empujado a que se creen patrones que permiten "actualizar" la lógica de los contratos inteligentes.

Algunos de los mecanismos usados para cambiar, aumentar o modificar la lógica de los contratos son los siguientes:

* El Patrón Diamante
* Contratos Actualizables (UUPS y transparente)
* Eternal Storage
* Contratos Metamórficos

En los tres primeros casos se logra separar la lógica de los contratos del storage. De modo tal que en estos casos existen dos contratos publicados que interactúan entre sí. Tenemos al contrato donde se guardan los estados y otro contrato donde se tiene la lógica para alterar los estados del primer contrato. Cada vez que se desea actualizar la lógica se vuelve a publicar un nuevo contrato. Paso seguido, se le avisa al contrato que guarda los estados que debe usar el address del nuevo contrato publicado.

El caso del Contrato Metamórfico es especial. En primer lugar, solo existe un contrato que guarda tanto los estados y también la lógica del contrato. Como consecuencia, solo existe un address para dicho contrato. En segundo lugar, es factible alterar la lógica de dicho contrato usando la misma address ya calculada previamente. Es como si se reemplazara nuevo código por el código antiguo que ya tenía el contrato. Ello es posible gracias a una combinación de diferentes opcodes que provee la EVM que se usan para crear contratos inteligentes: `CREATE` y `CREATE2`.

## Entendiendo `CREATE`

Este opcode crea un contrato inteligente y calcula el address de dicho contrato con los siguientes inputs:

* `sender_address`: address de la entidad que está creando el contrato
* `sender_nonce`: cantidad de transacciones realizadas por la entidad que crea el contrato (nonce inicial de EOA es 0 y de un contrato es 1). Se incrementa de manera consecutiva.

Vamos a suponer que es un contrato que está creando otro contrato usando el opcode `CREATE`. Expliquemos este proceso:

| Sender Address    | Sender Nonce | Contract Address |
| ----------------- | ------------ | ---------------- |
| 0xCreatorContract | 1            | 0xContractUno    |
| 0xCreatorContract | 2            | 0xContractDos    |
| ...               | ...          | ...              |

1. Se parte del address `0xCreatorContract` con nonce `1` (porque es un contrato) para crear un nuevo contrato con address `0xContratoUno`. Automáticamente el nonce de `0xCreatorContract` se incrementa a `2`.
2. Cuando `0xCreatorContract` posee un nonce de `2`, se crea un nuevo contrato con address `0xContratoDos`. Ahora el nonce de `0xCreatorContract` pasa de `2` a `3`. Dicho proceso se repite de manera similar.

Cabe mencionar que el nonce de `0xCreatorContract` se incrementa de manera automática por el protocolo.

### Punto clave

El punto clave de este proceso está comprender que, si de manera mágica, el nonce se puede resetear, podremos crear un contrato que usa la misma address antes ya publicada. Es más, este nuevo contrato vuelto a publicar en la misma address podría tener un código diferente. Ello porque al momento de calcular el address no se toma en consideración el código del contrato.

## Entendiendo `CREATE2`

Este opcode permite crear un address de un contrato inteligente de manera determinística. Es decir, si se llega usar los mismos inputs, se podrá generar la misma address. La principal diferencia entre el opcode `CREATE2` y `CREATE`, es que `CREATE2` no usa el nonce para calcular el address del contrato en creación. En cambio, require de los siguientes inputs:

* `0xff`: se usa como una fuente de entropía
* `sender_address`: address de la entidad creando el contrato
* `salt`: otra fuente de entropía dada por el usuario
* `keccak256(initialisation_code)`: bytecode del contrato a crear

Luego, aplicamos una función hash a dichos inputs para calcular el address:

`address = keccak256(0xff + sender_address + salt + keccak256(initialisation_code))[12:]`

### Code size y nonce

Una vez terminado el proceso de creación con `CREATE2`, el address ahora tendrá un `code size > 0` y un `nonce == 1`. Ello es lógico dado que ahora dicho address posee código, de modo que su `code size > 0`. Además, dado que es un contrato inteligente, su nonce comenzará en `1`.

### Validación

Para poder tener éxito en la creación de un contrato usando `CREATE2` se valida antes que dicha address se encuentre vacía. Ello quiere decir que dicha address debe tener un `code size == 0` y un `nonce == 0`. Es decir, que antes no se haya publicado ya un contrato inteligente en dicha address usando los mismos inputs. Si ese fuera el caso, la creación con `CREATE2` falla.

### Punto clave

Existe una manera en la cual se puede pasar de `code zise > 0` y `nonce == 1` a `code size == 0` y `nonce == 0`. Es decir, es posible resetear un address como si nunca se hubiera creado un contrato en dicha address. Para ello usaremos el opcode `SELFDESTRUCT`. Dentro de este nuevo contrato publicado se debe ejecutar `selfdestruct` para poder resetar su `code size` y `nonce`. Una vez que se ejecuta `selfdestruct` ya puedo publicar otra vez el mismo contrato empezando con un `nonce == 1`, como si fuera completamente nuevo. Aquí está el origen de la vulnerabilidad.

## Ejemplo práctico

Vamos a usar la figura del Conductor, Grúa y Edificios para entender cómo funcionan todas las partes.

En primer lugar vamos a ver cómo es posible que el Conductor puede crear Grúas mútiples veces usando la misma address para todas las Grúas.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

contract Conductor {
    address public gruaAddress;

    function crearGrua(uint256 _salt) public {
        Grua grua = new Grua{salt: bytes32(_salt)}();
        gruaAddress = address(grua);
    }
}

contract Grua {
    function destroy() public {
        selfdestruct(payable(msg.sender));
    }
}
```

1. Se publica el contrato del Conductor en una cierta address. Este contrato posee el método `crearGrua` que nos permitirá crear Grúas en una misma address como veremos a continuación.
2. Ejecutamos el método `crearGrua` con un `salt` cualquiera, digamos `1234`. Al hacerlo, se crea el primer contrato Grua en el address `0x3246C12fF8650C59f06fdB05eCb1DeD79Bea67Df`. 
3. Si en este preciso momento volvemos a ejecutar `crearGrua` con el mismo `salt`, dicha transacción fallará dado que el address `0x3246C12fF8650C59f06fdB05eCb1DeD79Bea67Df` ya posee código y además su `nonce` no es `0`.
4. Del contrato `Grua` llamamos el método `destroy`. Como resultado, el address `0x3246C12fF8650C59f06fdB05eCb1DeD79Bea67Df` es reseteado y su `code size` se hace `0` al igual que su `nonce` también.
5. Ahora sí puedo volver a publicar otra vez Grúa con el método `crearGrua` de Conductor. Al publicar el contrato Grúa por segunda vez obtendré el mismo address que hace un momento: `0x3246C12fF8650C59f06fdB05eCb1DeD79Bea67Df`.
6. Importante notar que aquí el contrato Grúa no se ha alterado en lo más mínimo. Ello porque en  `CREATE2` sí se toma en cuenta el bytecode del contrato para calcular su address. Por lo tanto aquí no nos importa aún modificar la lógica del contrato. Solo nos interesa resetear el `nonce` a `0`.

### Primer objetivo: resetear el nonce de Grúa

El objetivo de este primer ejercicio es notar que un contrato puede ser publicado en una misma address dos veces luego de que se ejecuta `SELFTDESCTRUCT`. Adicional a ello, notamos que un contrato puede regresar a un nonce inicial de 1 a pesar que dicha address haya realizado múltiples transacciónes. Aquí solo queremos regresar al nonce inicial. Ello porque cuando usamos `CREATE` para publicar un contrato sí se toma en cuenta el `nonce`.

### Preparando el ataque

Vamos a incluir código adicional en Grua que luego nos permitirá publicar un código diferente en la misma address. Por el momento lo dejamos del siguiente modo:

```solidity
// SPDX-License-Identifier: MIT
import {ERC20} from "@openzeppelin/contracts@4.6.0/token/ERC20/ERC20.sol";

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
```

### Secuencia del ataque

1. Se publica el contrato Conductor
2. El contrato Conductor publica el contrato Grua
3. El contrato Grua publica el EdificioUno
4. El contrato EdificioUno se autodestruye, regresando su code size y nonce a 0
5. El contrato Grua se autodestruye, regresando su code size y nonce a 0
6. El contrato Conductor vuelve a publicar Grua, el cual otra vez posee un nonce de 1
7. El contrato Grua publica esta vez el EdificioDos, que es el contrato con el nuevo código pero en la misma address en que estaba EdificioUno

De ese modo, en el paso 7 se puede colocar un código malicioso.

## SELFDESTRUCT es obsoleto

De acuerdo a [EIP-4758](https://eips.ethereum.org/EIPS/eip-4758), `SELFDESCTRUCT` será dado de baja en un hard fork en el futuro. `SELFDESTRUCT` será reemplazado por `SENDALL`. 

`SELFDESTRUCT` tiene la capacidad de remover el código y la información (storage) dicha cuenta. En cambio, `SENDALL` solo enviará los fondos a un objetivo pero no elimina ni código ni información (storage).

en [EIP-6049](https://eips.ethereum.org/EIPS/eip-6049) se busca poner `SELFDESCTRUCT` a un estado obsoleto. 
