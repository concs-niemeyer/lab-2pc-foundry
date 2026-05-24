# 🔗 Lab: Two-Phase Commit (2PC) + Blockchain Sepolia

Este laboratório prático simula o fluxo de uma **transação financeira distribuída** utilizando o protocolo **Two-Phase Commit (2PC)** e integra uma camada de auditoria descentralizada e imutável através de um Smart Contract na rede de teste **Sepolia (Ethereum)**.

O objetivo principal é entender como coordenar o consenso em sistemas distribuídos tradicionais e, ao mesmo tempo, garantir transparência e não-repúdio registrando a decisão final (COMMIT ou ABORT) em uma blockchain.

---

## 🌟 O Cenário de Negócio

Simulamos uma transferência bancária entre dois participantes distribuídos:
* **Banco A (Origem):** Possui saldo inicial de **R$ 100**. Será debitado em R$ 50 se a transação for confirmada.
* **Banco B (Destino):** Possui saldo inicial de **R$ 20**. Será creditado em R$ 50 se a transação for confirmada.

### O Desafio
Em sistemas distribuídos, a transferência não pode ser feita às cegas. Se o saldo do Banco A for insuficiente ou se o Banco B estiver fora do ar, a transação inteira deve ser cancelada (**atomicidade** - tudo ou nada). É aí que entra o protocolo **2PC** coordenado.

---

## 🏗️ Arquitetura do Sistema

A arquitetura do laboratório é composta por quatro elementos principais:

```
                  +--------------------------------+
                  |         Cliente / Trigger      |
                  +---------------+----------------+
                                  |
                                  v
                  +--------------------------------+
                  |     Coordenador 2PC (JS)       |
                  +-------+----------------+-------+
                          |                |
             (PREPARE)    |                |    (PREPARE)
             (COMMIT/     |                |    (COMMIT/
              ABORT)      v                v     ABORT)
                  +---------------+        +---------------+
                  |  Banco A (JS) |        |  Banco B (JS) |
                  |  Porta 5001   |        |  Porta 5002   |
                  +---------------+        +---------------+
                          |
             (Registrar   |
              Decisão)    v
                  +--------------------------------+
                  |     Smart Contract Sepolia     |
                  |     (CommitLog.sol)            |
                  +--------------------------------+
```

---

## 🔄 Funcionamento do Two-Phase Commit (2PC) neste Lab

O protocolo 2PC é dividido em duas fases síncronas gerenciadas pelo **Coordenador**:

### Fase 1: Preparação (*Prepare Phase*)
1. O Coordenador gera um identificador único para a transação (`tx-<timestamp>`).
2. O Coordenador envia uma mensagem do tipo `PREPARE` contendo o `transactionId` e o `amount` (R$ 50) para ambos os bancos via conexões de socket TCP.
3. **Banco A** verifica se possui saldo suficiente (Saldo R$ 100 >= R$ 50). Como possui, reserva os recursos internamente e responde com o voto **`YES`**.
4. **Banco B** responde confirmando que está online e pronto para receber, votando **`YES`**.

### Fase 2: Decisão (*Commit/Abort Phase*)
1. O Coordenador coleta os votos de todos os participantes.
2. **Caso de Sucesso (Todos votaram `YES`):** O Coordenador decide por **`COMMIT`** e envia essa mensagem de confirmação para os dois bancos. 
   * O Banco A efetiva o débito (novo saldo: R$ 50).
   * O Banco B efetiva o crédito (novo saldo: R$ 70).
3. **Caso de Falha (Pelo menos um voto `NO` ou timeout):** O Coordenador decide por **`ABORT`** e envia essa instrução a todos.
   * Os bancos desfazem qualquer reserva temporária e mantêm seus saldos inalterados.
4. **Registro na Blockchain:** Independentemente do resultado (`COMMIT` ou `ABORT`), o Coordenador se comunica com a rede Sepolia através de uma transação Web3 e grava a decisão final de forma permanente e imutável no contrato inteligente `CommitLog`.

---

## 📁 Estrutura de Pastas do Projeto

```text
lab-2pc-foundry/
├── .env                       # Variáveis de ambiente (chaves privadas, RPC, contrato)
├── foundry.toml               # Configuração do framework Foundry (Solidity compiler 0.8.24)
├── package.json               # Configurações do ecossistema Node.js e dependências
├── bankA.js                   # Simulação do Banco A (Servidor TCP na porta 5001)
├── bankB.js                   # Simulação do Banco B (Servidor TCP na porta 5002)
├── coordinator.js             # O Coordenador 2PC e integrador Web3 (Ethers.js)
├── LOG_aula_06.txt            # Exemplo de log de execução bem-sucedido
│
├── src/
│   └── CommitLog.sol          # Smart Contract Solidity para registro de auditoria imutável
│
├── script/
│   └── DeployCommitLog.s.sol  # Script do Foundry para deploy do CommitLog
│
└── test/
    └── CommitLog.t.sol        # Testes unitários para validar a lógica do Smart Contract
```

---

## 💻 Detalhes dos Componentes de Código

### 1. Smart Contract: `src/CommitLog.sol`
Escrito em Solidity `^0.8.24`, este contrato armazena o histórico histórico das transações.
* **Enum `Decision`**: Define os estados `UNKNOWN` (0), `COMMIT` (1) e `ABORT` (2).
* **Struct `TransactionRecord`**: Guarda os dados de cada transação registrada:
  * `transactionId` (string)
  * `decision` (Enum Decision)
  * `timestamp` (uint256)
  * `coordinator` (address de quem registrou)
  * `value` (uint256, valor financeiro da transação)
* **Função `recordDecision`**: Registra uma nova decisão. Ela garante através de `require` que:
  * A transação ainda não tenha sido registrada anteriormente (garantia de unicidade).
  * Apenas decisões válidas (`COMMIT` ou `ABORT`) sejam inseridas.
* **Função `getDecision`**: Função de visualização pública para consultar os dados de qualquer transação registrada pelo ID.

### 2. Participantes TCP: `bankA.js` & `bankB.js`
São servidores simples em Node.js usando o módulo nativo `net` (Sockets).
* O **Banco A** inicia com `balance = 100` e valida dinamicamente no `PREPARE` se o valor solicitado é menor ou igual ao seu saldo corrente. Se for menor, envia voto `YES`, senão `NO`.
* O **Banco B** inicia com `balance = 20` e atua apenas como recebedor, votando `YES` na fase de preparação.

### 3. O Coordenador: `coordinator.js`
Utiliza a biblioteca `ethers.js` para interagir com a blockchain e gerencia o fluxo lógico de rede:
* Estabelece comunicação assíncrona com os bancos via sockets.
* Avalia a regra de consenso (se todos votam `YES` -> COMMIT, senão -> ABORT).
* Notifica os bancos do resultado final.
* Instancia a carteira do coordenador através de chave privada e envia a transação `recordDecision` para a blockchain Sepolia.

---

## 🛠️ Pré-requisitos para Execução

Antes de começar, certifique-se de ter instalado em sua máquina:
1. [Node.js](https://nodejs.org/) (v18 ou superior recomendado)
2. [Foundry Toolkit](https://book.getfoundry.sh/getting-started/installation) (para compilar, testar e fazer o deploy dos contratos Solidity)

---

## 🚀 Passo a Passo para Configuração e Execução

### 1. Configurando o Ambiente Node.js
No diretório raiz do projeto, instale as dependências necessárias (`ethers` para Web3 e `dotenv` para leitura de ambiente):
```bash
npm install
```

### 2. Compilação e Testes do Smart Contract (Foundry)
Você pode rodar os testes unitários locais para garantir que a lógica do Smart Contract está perfeita antes de ir para a rede pública.

* **Compilar os contratos:**
  ```bash
  forge build
  ```

* **Executar os testes locais:**
  ```bash
  forge test -vvv
  ```
  *(Os testes em `test/CommitLog.t.sol` validam se é possível gravar decisões, se há barreira contra gravação duplicada e se decisões inválidas são rejeitadas).*

### 3. Configurando as Variáveis de Ambiente
Crie ou configure o arquivo `.env` na raiz do projeto contendo as credenciais de acesso para a rede de testes Sepolia.

Exemplo de estrutura do `.env`:
```env
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/SUA_API_KEY
PRIVATE_KEY=0xSUA_CHAVE_PRIVADA_DA_CARTEIRA
CONTRACT_ADDRESS=0xENDERECO_DO_CONTRATO_DEPLOYADO
```

> 💡 **Nota:** Se você deseja subir seu próprio contrato, você pode fazer o deploy usando o script do Foundry:
> ```bash
> forge script script/DeployCommitLog.s.sol --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast
> ```
> Após o sucesso do deploy, copie o endereço gerado e insira-o no campo `CONTRACT_ADDRESS` do seu `.env`.

### 4. Executando a Simulação da Transação Distribuída

Para ver o Two-Phase Commit e a integração com a Blockchain em funcionamento, você precisará de 3 terminais abertos:

#### Terminal 1: Iniciar o Banco A
```bash
node bankA.js
```
*Saída esperada:* `[Banco A] Escutando na porta 5001`

#### Terminal 2: Iniciar o Banco B
```bash
node bankB.js
```
*Saída esperada:* `[Banco B] Escutando na porta 5002`

#### Terminal 3: Executar o Coordenador 2PC
```bash
node coordinator.js
```

---

## 📊 Exemplo Prático de Saída no Coordenador

Quando o coordenador roda com sucesso, ele inicia o processo, negocia com os bancos distribuídos e gera a transação na Sepolia de forma automatizada:

```text
Iniciando transação tx-1234567890
Transferência: Banco A -> Banco B | Valor: 50
[Coordenador] Voto de Banco A: YES
[Coordenador] Voto de Banco B: YES
[Coordenador] Decisão final: COMMIT
[Coordenador] Registrando decisão na Sepolia...
[Coordenador] Decisão registrada na blockchain.
Hash da transação: 0xXXXXXXXXXXXXXXXXXXXXXXXX
```

Enquanto isso, nos terminais dos bancos, você verá as atualizações correspondentes:
* **Terminal do Banco A:**
  ```text
  [Banco A] PREPARE recebido
  [Banco A] COMMIT. Novo saldo: 50
  ```
* **Terminal do Banco B:**
  ```text
  [Banco B] PREPARE recebido
  [Banco B] COMMIT. Novo saldo: 70
  ```

---

## 🛡️ Benefícios da Integração de 2PC com Blockchain neste Lab

1. **Consistência Sem Latência Excessiva:** Os bancos efetuam a transação rapidamente após o acordo de duas fases, garantindo consistência imediata entre Banco A e Banco B.
2. **Auditabilidade Descentralizada:** Um terceiro validador ou auditor não precisa confiar no banco de dados interno de nenhum dos bancos para provar que a transferência ocorreu; basta verificar o `CommitLog` público no endereço do contrato inteligente da Sepolia utilizando o ID da transação.
3. **Não-Repúdio:** Nenhuma das partes (nem os bancos, nem o coordenador) pode mentir sobre o resultado da transação ou alterar o registro histórico, devido à imutabilidade da blockchain.


## 🔍 Consulta Direta à Blockchain via CLI (Foundry `cast`)

Para auditar e verificar o status de uma transação diretamente na rede Sepolia sem precisar de uma interface gráfica, você pode utilizar o **`cast`**, o utilitário de linha de comando do framework Foundry.

### 1. Comando de Consulta e Decodificação

Certifique-se de que suas variáveis de ambiente estejam devidamente carregadas no seu terminal (ou substitua-as diretamente no comando) e execute o comando abaixo (ajustando o ID da transação, por exemplo, `tx-1779659704946`):

```bash
cast call --rpc-url $SEPOLIA_RPC_URL $CONTRACT_ADDRESS "getDecision(string)" "tx-1779659704946" | xargs cast decode-abi "getDecision(string)(uint8,uint256,address,uint256)"
```

### 2. Entendendo o Retorno do Comando

O comando acima realiza a chamada de leitura ao contrato inteligente (`cast call`) e passa o resultado hexadecimal pelo pipe (`|`) para ser decodificado (`cast decode-abi`) de acordo com o formato de retorno do Smart Contract.

A saída no terminal será semelhante a esta:

```text
1
1779659712
0x4c6fB514372781d0D42D8b29FB4bB65FF3964151
50
```

Cada uma dessas linhas decodificadas corresponde a um campo do registro guardado na blockchain:

| Linha | Tipo Solidity | Campo no Contrato | Valor Exemplo | Significado / Descrição |
| :---: | :---: | :--- | :--- | :--- |
| **1** | `uint8` | `decision` | `1` | Decisão da transação registrada no Enum (`0 = UNKNOWN`, `1 = COMMIT`, `2 = ABORT`). |
| **2** | `uint256` | `timestamp` | `1779659712` | Carimbo de data/hora no padrão Unix Epoch de quando o registro foi gravado na rede. |
| **3** | `address` | `coordinator` | `0x4c6fB514372781d0D42D8b29FB4bB65FF3964151` | Endereço da carteira Ethereum do Coordenador que assinou e enviou a transação. |
| **4** | `uint256` | `value` | `50` | O valor financeiro da transação que foi acordado e liquidado (R$ 50). |

> [!TIP]
> Você pode converter o timestamp Unix para uma data legível no Linux executando o comando:
> `date -d @1779659712` (ou no macOS com `date -r 1779659712`).