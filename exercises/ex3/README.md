# Exercício 3: Replicação e Eventos

Na lista de incidentes, a aplicação deve exibir dados do cliente (remotos) juntamente com dados de incidentes (locais da aplicação).
Isso levanta um **problema de desempenho**: ao mostrar potencialmente centenas de incidentes, o aplicativo deve chegar ao sistema remoto? Ou apenas para registros únicos, para todos os registros de uma vez ou para um conjunto de registros?

Usamos uma abordagem diferente ao **replicar dados remotos sob demanda**.

O cenário ficará assim:
- O usuário insere uma nova ocorrência e seleciona o cliente através da ajuda de valor. A ajuda do valor mostra apenas dados do cliente _remote_.
- Assim que o registro do incidente é criado, os dados do cliente são gravados em uma tabela de réplica local.
- Outras solicitações para o cliente do incidente são atendidas nesta tabela de réplica.
- Os registros replicados serão atualizados se um cliente remoto mudar.

👉 Comece **adicionando uma tabela persistente** para as réplicas. Isso pode ser feito com apenas uma linha em `db/data-model.cds`:

```cds
annotate Customers with @cds.persistence.table;
```

A anotação `@cds.persistence.table` transforma a visualização acima em uma tabela com a mesma assinatura (colunas `ID` e `name`). Consulte a [documentação](https://cap.cloud.sap/docs/cds/annotations#persistence) para saber mais sobre anotações que influenciam a persistência.

> Você poderia ter adicionado a anotação diretamente à definição de `Customers`. O resultado seria o mesmo. Porém, com a [diretiva `annotate`](https://cap.cloud.sap/docs/cds/cdl#the-annotate-directive), você obtém o poder de aprimorar entidades (até mesmo entidades externas/base/reutilizáveis!) em diferentes locais da sua aplicação.

## Replicar dados sob demanda

Agora é necessário um código para replicar o registro do cliente sempre que um incidente é criado.

👉 No arquivo `srv/processor-service.js`, adicione este código (à função `init`):

```js
  const db = await cds.connect.to('db')                // our primary database
  const { Customers }  = db.entities('incidents.mgt')  // CDS definition of the Customers entity

  this.after (['CREATE','UPDATE'], 'Incidents', async (data) => {
    const { customer_ID: ID } = data
    if (ID) {
      console.log ('>> Updating customer', ID)
      const customer = await S4bupa.read (Customers,ID) // read from remote
      await UPSERT(customer) .into (Customers)          // update cache
    }
  })
```

👉 Agora crie um incidente na UI. Não se esqueça de selecionar um cliente através da ajuda de valor.<br>
No log, você pode ver a linha `>> Atualizando cliente`, confirmando que a replicação acontece.

## Teste sem UI

Com o [cliente REST para VS Code](https://marketplace.visualstudio.com/items?itemName=humao.rest-client), você pode testar convenientemente o mesmo fluxo sem a UI.

👉 Crie um arquivo `tests.http` com este conteúdo:

```
###
# @name IncidentsCreate

POST http://localhost:4004/odata/v4/processor/Incidents
Content-Type: application/json

{
  "title": "New incident",
  "customer_ID": "1001039"
}

###
@id = {{IncidentsCreate.response.body.$.ID}}

POST http://localhost:4004/odata/v4/processor/Incidents(ID={{id}},IsActiveEntity=false)/draftActivate
Content-Type: application/json
```

👉 Clique em `Enviar solicitação` acima da linha `POST .../Incidents`. Isso criará o registro em um projeto de lei.<br>
👉 Clique em `Enviar solicitação` acima da linha `POST .../draftActivate`. Isso corresponde à ação `Salvar` na UI.

  > Esta segunda solicitação é necessária para todas as alterações em entidades gerenciadas pelo mecanismo [rascunho do SAP Fiori](https://cap.cloud.sap/docs/advanced/fiori#draft-support).

Você deverá ver o mesmo log do servidor `>> Atualizando o cliente`.


## Replicação baseada em eventos

Ainda não discutimos como _atualizar_ a tabela de cache que contém os dados de `Customers`. Usaremos _events_ para informar nosso aplicativo sempre que o BusinessPartner remoto for alterado.

Vamos ver o que o pacote de integração oferece.

👉 Abra `node_modules/s4-bupa-integration/bupa/index.cds`

<detalhes>
<summary>Pergunta rápida: como você pode pular para este arquivo bem rápido?</summary>

Use a saída `cds watch` no console. O arquivo está listado lá porque é carregado quando o aplicativo é iniciado.

<kbd>Ctrl+Clique</kbd> no arquivo para abri-lo:

![Ir para o arquivo no console](assets/ConsoleJumpToFile.png)
</detalhes>

<p>

Lá você pode ver que as definições de evento para `BusinessPartner` estão disponíveis:

```cds
event BusinessPartner.Created @(topic : 'sap.s4.beh.businesspartner.v1.BusinessPartner.Created.v1') {
  BusinessPartner : S4.A_BusinessPartner:BusinessPartner;
}
event BusinessPartner.Changed @(topic : 'sap.s4.beh.businesspartner.v1.BusinessPartner.Changed.v1') {
  BusinessPartner : S4.A_BusinessPartner:BusinessPartner;
}
```

Os benefícios dessas definições de eventos 'modelados' são:
- [O suporte do CAP para eventos e mensagens](https://cap.cloud.sap/docs/guides/messaging) pode _inscrever-se_ automaticamente para corretores de mensagens e _emitir_ eventos nos bastidores.
- Além disso, nomes de eventos como `BusinessPartner.Changed` são semanticamente mais próximos do domínio e mais fáceis de ler do que os eventos técnicos subjacentes como `sap.s4.beh.businesspartner.v1.BusinessPartner.Changed.v1`.


## Reaja aos eventos

Para fechar o loop, adicione código a **consumir eventos**.

👉 Em `srv/processor-service.js`, adicione este manipulador de eventos:

```js
    // update cache if BusinessPartner has changed
    S4bupa.on('BusinessPartner.Changed', async ({ event, data }) => {
      console.log('<< received', event, data)
      const { BusinessPartner: ID } = data
      const customer = await S4bupa.read (Customers, ID)
      await UPSERT.into (Customers) .entries (customer)
    })
```

## Emitindo eventos de serviços simulados

Mas quem é o **emissor do evento**? Geralmente é a fonte de dados remota, ou seja, o sistema SAP S4/HANA. Para execuções locais, seria ótimo se algo pudesse **emitir eventos durante o teste**. Felizmente, já existe um emissor de eventos simples no pacote de integração!

👉 Abra o arquivo `node_modules/s4-bupa-integration/bupa/API_BUSINESS_PARTNER.js`.<br>
Você sabe como pode abri-lo bem rápido, não é? :)

Ele usa a [API `emit`](https://cap.cloud.sap/docs/node.js/core-services#srv-emit-event) para enviar um evento:

```js
  ...
  this.after('UPDATE', A_BusinessPartner, async data => {
    const event = { BusinessPartner: data.BusinessPartner }
    console.log('>> BusinessPartner.Changed', event)
    await this.emit('BusinessPartner.Changed', event);
  })
  this.after('CREATE', A_BusinessPartner, ...)
```

Isso significa que sempre que você altera ou cria dados por meio do serviço simulado `API_BUSINESS_PARTNER`, um evento local é emitido.
Observe também como o nome do evento `BusinessPartner.Changed` corresponde à definição do evento do código CDS acima.

## Junte tudo

Antes de iniciar o aplicativo novamente, é hora de transformar o banco de dados atual na memória em um banco de dados persistente. Dessa forma, os dados não são redefinidos após cada reinicialização, o que é útil se você adicionou dados manualmente.

👉 Então, mate `cds watch` e execute:

```sh
cds deploy --with-mocks --to sqlite
```

> Isso implanta o equivalente SQL atual do seu modelo CDS em um banco de dados persistente. Isso também significa que após alterações no modelo de dados (novos campos, entidades etc.), você precisa executar o comando `cds deploy ...` novamente. Tenha isso em mente caso você veja erros como _tabela/visualização não encontrada_.

<!-- Você também pode querer abrir o arquivo `db.sqlite` e inspecionar o conteúdo do banco de dados:
![Conteúdo do banco de dados](assets/sqlite-dump.png) -->


👉 Inicie a aplicação com uma dica para usar um banco de dados SQLite (que neste caso significa um banco de dados persistente):

```sh
CDS_REQUIRES_DB=sqlite cds watch
```

> `CDS_REQUIRES_DB=sqlite` tem o mesmo efeito que `"cds": { "requires": { db:"sqlite" } }` em `package.json`, só que o último é uma configuração permanente.

O aplicativo é executado como antes. No log, entretanto, você não vê mais uma implantação de banco de dados, mas uma linha como:

```sh
...
[cds] - connect to db > sqlite { url: 'db.sqlite' }
...
```

👉 No seu arquivo `tests.http`, primeiro execute as 2 solicitações para **criar um incidente** novamente (veja [seção acima](#test-without-ui)).

Agora **altere o cliente** `1001039` com uma solicitação HTTP. Adicione esta solicitação ao arquivo `http`:

```
###
PUT http://localhost:4004/odata/v4/api-business-partner/A_BusinessPartner/1001039
Authorization: Basic carol:
Content-Type: application/json

{
  "BusinessPartnerFullName": "Cathrine Cloudy"
}
```

👉 Após clicar em `Send Request` acima da linha `PUT ...`, você deverá ver tanto o evento sendo emitido quanto recebido:

```
>> BusinessPartner.Changed { BusinessPartner: 'Z100001' }
<< received BusinessPartner.Changed { BusinessPartner: 'Z100001' }
```

A UI do SAP Fiori também reflete os dados alterados na lista de incidentes:

![Lista de clientes atualizada](assets/updated-customer.png)

> Observe que não podemos testar o evento de ida e volta no modo `cds watch --profile sandbox`, pois o sistema sandbox do _SAP Business Accelerator Hub_ não suporta modificações. Você precisaria usar um sistema SAP S/4HANA dedicado aqui. Consulte este [tutorial](https://developers.sap.com/tutorials/btp-app-ext-service-s4hc-register.html) para saber como registrar seu próprio sistema SAP S/4HANA.


## Resumo

Neste e no último exercício, você aprendeu como adicionar um pacote de integração. Você também viu que alguns códigos de aplicativos poderiam ser evitados, a saber:

- A descrição da API BusinessPartner para a estrutura (entidades, tipos etc), conforme modelo CDS
- As definições do evento BusinessPartner, conforme modelo CDS
- A implementação simulada do serviço e dados de amostra
- Emissores de eventos para testes locais

Dependendo do cenário da aplicação, mais recursos de nível superior podem ser adicionados a esses pacotes, como

- Projeções CDS para peças de modelo que são frequentemente utilizadas, como uma definição de `Customers`.
- Anotações adicionais, como para SAP Fiori Elements
- Conteúdo traduzido como arquivos i18n

A imagem a seguir mostra como o pacote de integração/reutilização e o projeto do aplicativo funcionam juntos em nível técnico.

![](assets/reuse-overview.drawio.svg)


Vamos fazer um resumo geral(../summary/) do que você viu.