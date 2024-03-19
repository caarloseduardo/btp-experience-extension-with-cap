# Exercício 2 - Integração de serviços com SAP S/4 HANA

Neste exercício, você adicionará `Customers` a `Incidents` para especificar quem criou um incidente.

![Modelo de domínio](../ex1/assets/domain.drawio.svg)

Os dados do cliente estão disponíveis no _SAP S/4HANA Cloud_ como parte do serviço _Business Partners_. Você se conectará a este serviço a partir do aplicativo _Gerenciamento de Incidentes_.


## Confira a versão base do aplicativo

Para lhe proporcionar um início consistente para as próximas tarefas, há uma versão inicial do aplicativo disponível. Basicamente corresponde ao que você fez no último exercício, além de ter alguns pedaços de UI.

> Recomendamos começar neste ramo. Você pode salvar seu trabalho anterior enviando-o para um repositório do Github, por exemplo.

👉 Clone este repositório e verifique o branch `start`:

```sh
cd /home/user/projects
git clone -b start https://github.com/caarloseduardo/btp-experience-extension-with-cap
cd btp-experience-extension-with-cap
npm ci  # installs app's dependencies
```

👉 Em seguida, abra a nova pasta `btp-experience-extension-with-cap` em uma nova janela:

![Abrir pasta](assets/BAS-OpenFolder.png)

![Selecionar pasta](assets/BAS-OpenFolder-2.png)

> Alternativamente, você pode usar o comando _SAP Business Application Studio: Git Clone_


## Adicionar pacote de integração

Felizmente, você não precisa implementar a integração ao SAP S/4HANA do zero, mas pode usar um pacote de integração.<br>
Esses pacotes podem vir de qualquer provedor: SAP, parceiros, uma equipe da sua empresa, etc. Eles podem ser publicados em npmjs.com ou fornecidos como arquivos tar simples de um servidor de arquivos remoto ou de uma pasta local.

Por conveniência, usamos uma dependência `git` para uma ramificação neste repositório como fonte do pacote.

👉 No terminal, execute isto para baixar o pacote:

```sh
npm add git+https://github.com/SAP-samples/teched2023-AD264#bupa-integration-package
```

👉 Vamos ver o que foi instalado. Expanda a pasta `node_modules/s4-bupa-integration` (no explorador de arquivos ou no terminal):

```
node_modules/s4-bupa-integração
├── bupa
│   ├── API_BUSINESS_PARTNER.cds
│   ├── API_BUSINESS_PARTNER.csn
│   ├── API_BUSINESS_PARTNER.edmx
│   ├── API_BUSINESS_PARTNER.js
│   ├── data
│   │   └── API_BUSINESS_PARTNER-A_BusinessPartner.csv
│   └── index.cds
└── package.json
```

👉 Abra o arquivo `API_BUSINESS_PARTNER.cds` (não o arquivo `.csn`)
- Encontre a visualização do esboço no canto inferior esquerdo da janela. Alternativamente, pressione <kbd>F1></kbd>, digite _outline_ e selecione _Explorer: Focus on Outline View_.
- Use a visualização para se familiarizar com quais entidades existem. <br>
  ![Visualização de esboço do arquivo API_BUSINESS_PARTNER.cds](assets/Outline-CDS.png)

  Uma API e tanto, certo? Não se preocupe, em breve restringiremos ao que precisamos no aplicativo.

👉 Primeiro, para fazer com que o modelo CDS da aplicação utilize o pacote, adicione esta linha em `db/data-model.cds`:

```cds
using { API_BUSINESS_PARTNER as S4 } from 's4-bupa-integration/bupa';
```

> Observe como o caminho em `from 's4-bupa-integration/bupa'` corresponde ao caminho do arquivo em `node_modules`.

👉 Cadastre o pacote na configuração do aplicativo. Adicione este nível superior ao `package.json` (preste atenção aos erros de sintaxe JSON):

```jsonc
  "cds": {
    "requires": {
      "API_BUSINESS_PARTNER": {
        "kind": "odata-v2",
        "model": "s4-bupa-integration/bupa"
      }
    }
  }
```


## Adaptação de serviço

Para a primeira versão da aplicação, são necessários apenas dois campos da entidade `A_BusinessPartner`. Para fazer isso, crie uma [_projection_](https://cap.cloud.sap/docs/guides/using-services#model-projections) no serviço externo. Como neste exemplo você está interessado em parceiros de negócios na função de cliente, use o nome `Customers` para sua projeção.

👉 Adicionar `Customers`:
- Crie uma entidade `Customers` como projeção para a entidade `A_BusinessPartner` que você acabou de importar. Deve ter dois campos
   - `ID` para o `BusinessPartner` remoto
   - `name` para o `BusinessPartnerFullName` remoto
- Adicione uma associação de `Incidents` a (um) `Customer`
- Expor a entidade `Customers` semelhante a `Incidents`

<details>
<summary>É assim que se faz:</summary>

Adicione isto a `db/data-model.cds`:

```cds
entity Customers   as projection on S4.A_BusinessPartner {
  key BusinessPartner         as ID,
      BusinessPartnerFullName as name
}
```

Em seguida, adicione:

```cds
extend Incidents with {
  customer      : Association to Customers;
}
```

Em `srv/processor-service.cds`, adicione esta linha:

```cds
extend service ProcessorService with {
  entity Customers as projection on mgt.Customers;
}
```

Novamente, você poderia ter adicionado esses novos campos e entidades às definições originais. Dessa forma, porém, é mais fácil copiar. Além disso, mostra como adicionar coisas de uma forma “livre de modificações”.

</details>

## Teste com serviços simulados

👉 Execute `cds watch` novamente e verifique sua saída. Você encontra as informações sobre o que está acontecendo:

```sh
...
  > init from node_modules/s4-bupa-integration/bupa/data/API_BUSINESS_PARTNER-A_BusinessPartner.csv
...
[cds] - mocking API_BUSINESS_PARTNER {
  path: '/odata/v4/api-business-partner',
  impl: 'node_modules/s4-bupa-integration/bupa/API_BUSINESS_PARTNER.js'
}
```

Você viu isso

- O `API_BUSINESS_PARTNER` externo é simulado, ou seja, servido na aplicação embora em produção venha de forma remota. Isso ocorre porque ainda não especificamos como conectá-lo a uma fonte de dados remota real.
- Um arquivo CSV `.../data/API_BUSINESS_PARTNER-A_BusinessPartner.csv` com dados simulados foi implantado.<br>De onde ele vem? Sim, o pacote de integração. Veja a árvore de arquivos desde o início onde está listada.

> `cds watch` roda em 'modo simulado' por padrão. Em produção, isso não acontecerá, pois a aplicação é iniciada com `cds-serve`. Consulte a [documentação](https://cap.cloud.sap/docs/guides/extensibility/composition#testing-locally) para saber como o `cds watch` se vincula aos serviços.

👉 Acesse a página inicial do aplicativo (aquela que lista todos os endpoints de serviço).<br>

Você pode ver o serviço `/odata/v4/api-business-partner` com todas as suas entidades em _Service Endpoints_.
Os dados estão disponíveis em `/odata/v4/api-business-partner/A_BusinessPartner`.

![Parceiro de negócios na lista de endpoints](./assets/api-business-partner-service.png)

## Delegar chamadas para o sistema remoto

Para fazer com que as solicitações de `Customers` funcionem de verdade, você precisa redirecioná-los para o sistema remoto.

👉 No arquivo `srv/processor-service.js`, adicione este conteúdo à função `init`:

```js
  // connect to S4 backend
  const S4bupa = await cds.connect.to('API_BUSINESS_PARTNER')
  // delegate reads for Customers to remote service
  this.on('READ', 'Customers', async (req) => {
    console.log(`>> delegating '${req.target.name}' to S4 service...`, req.query)
    const result = await S4bupa.run(req.query)
    return result
  })
```

> Observe como você não precisa codificar em nenhuma camada de baixo nível aqui. É apenas o nome do serviço `API_BUSINESS_PARTNER` que é relevante. O resto está conectado nos bastidores ou fora do código do aplicativo. Como? Continue lendo!

👉 Abra `/odata/v4/processor/Customers` para ver os dados simulados do serviço `BusinessPartner`.

Vamos mudar isso e configurar um sistema remoto.


## Teste com sistema remoto

Como substituto pronto para uso de um sistema SAP S4/HANA, usamos o sistema sandbox do _SAP Business Accelerator Hub_.

> Para usar seu próprio sistema SAP S/4HANA Cloud, consulte este [tutorial](https://developers.sap.com/tutorials/btp-app-ext-service-s4hc-use.html). Você não precisa disso para este tutorial.

👉 Crie um **novo arquivo `.env`** na pasta raiz e adicione **variáveis de ambiente** que contêm a URL do sandbox, bem como uma chave de API pessoal:

```properties
DEBUG=remote
cds.requires.API_BUSINESS_PARTNER.[sandbox].credentials.url=https://sandbox.api.sap.com/s4hanacloud/sap/opu/odata/sap/API_BUSINESS_PARTNER/
cds.requires.API_BUSINESS_PARTNER.[sandbox].credentials.headers.APIKey=<Copied API Key>
```

Observe o segmento `[sandbox]` que denota um [perfil de configuração](https://cap.cloud.sap/docs/node.js/cds-env#profiles) chamado `sandbox`. O nome não tem nenhum significado especial. Você verá abaixo como usá-lo.

<details>
<summary>Como alternativa, obtenha uma chave de API para seu usuário pessoal:</summary>

Para obter uma chave de API para seu usuário pessoal do _SAP Business Accelerator Hub_:

- Acesse [SAP Business Accelerator Hub](https://api.sap.com).
- No canto superior direito, expanda o menu suspenso _Olá ..._. Escolha _Configurações_.
- Clique em _Mostrar chave API_. Escolha _Copiar chave e fechar_.

   ![Obter chave de API do SAP API Business Hub](./assets/hub-api-key.png)
</details>

<p>

👉 **Adicione a chave** ao arquivo `.env`

Ao colocar a chave em um arquivo separado, você pode excluí-la do repositório Git (veja o arquivo `.gitignore`).<br>

> Observe como a estrutura `cds.requires.API_BUSINESS_PARTNER` no arquivo `.env` corresponde à configuração `package.json`.<br>
Para saber mais opções de configuração para aplicativos CAP Node.js, consulte a [documentação](https://cap.cloud.sap/docs/node.js/cds-env).

👉 Agora mate o servidor com <kbd>Ctrl+C</kbd> e execute novamente com o perfil `sandbox` ativado:

```sh
cds watch --profile sandbox
```

No log do servidor, você pode ver que a configuração está efetiva:

```sh
...
[cds] - connect to API_BUSINESS_PARTNER > odata-v2 {
  url: 'https://sandbox.api.sap.com/s4hanacloud/sap/opu/odata/sap/API_BUSINESS_PARTNER/',
  headers: { APIKey: '...' }
}
...
```

Na página de índice da aplicação, o **serviço simulado desapareceu**, porque não é mais servido na aplicação. Em vez disso, presume-se que ele esteja **executando em um sistema remoto**. Através da configuração acima, o sistema sabe como se conectar a ele.

👉 Abra `/odata/v4/processor/Customers` para ver os dados provenientes do sistema remoto.

> Se você receber um erro `401`, verifique sua chave de API no arquivo `.env`. Após uma mudança na configuração, mate o servidor com <kbd>Ctrl+C</kbd> e reinicie-o.

Você também pode ver algo assim no log (devido à variável `DEBUG=remote` do arquivo `.env` acima):

```
[remote] - GET https://.../API_BUSINESS_PARTNER/A_BusinessPartner
  ?$select=BusinessPartner,BusinessPartnerFullName&$inlinecount=allpages&$top=74&$orderby=BusinessPartner%20asc
...
```

Esta é a solicitação remota enviada pelo framework quando `S4bupa.run(req.query)` é executado. O objeto **`req.query` é traduzido de forma transparente para uma consulta OData** `$select=BusinessPartner,BusinessPartnerFullName&$top=...&$orderby=...`. A solicitação HTTP inteira (concluída pela configuração do URL do sandbox) é então enviada ao sistema remoto com a ajuda do **SAP Cloud SDK**.

Observe como é **simples** a execução de consultas remotas. Nenhuma construção manual de consulta OData é necessária, nenhuma configuração de cliente HTTP como autenticação, nenhuma análise de resposta, tratamento de erros, nem problemas com nomes de host conectados, etc.

> Consulte a [documentação sobre CQN](https://pages.github.tools.sap/cap/docs/cds/cqn) para obter mais informações sobre essas consultas em geral. O [guia de consumo de serviços](https://pages.github.tools.sap/cap/docs/guides/using-services#execute-queries) detalha como eles são traduzidos para solicitações remotas.

> Os aplicativos CAP usam o [SAP Cloud SDK](https://sap.github.io/cloud-sdk/) para conectividade HTTP. O SAP Cloud SDK abstrai fluxos de autenticação e comunicação com SAP BTPs [conectividade, destino e autenticação](https://sap.github.io/cloud-sdk/docs/js/features/connectivity/destination).
Não importa se você deseja se conectar à nuvem ou a sistemas locais.

## Concluir a UI

A UI precisa de mais algumas anotações para mostrar os dados alterados.

👉 Primeiro, algumas anotações básicas que se referem aos próprios `Customers`. Adicione-o a `app/incidents/annotations.cds`:

```cds
annotate service.Customers with @UI.Identification : [{ Value:name }];
annotate service.Customers with @cds.odata.valuelist;
annotate service.Customers with {
  ID   @title : 'Customer ID';
  name @title : 'Customer Name';
};
```

👉 Também em `app/incidents/annotations.cds`, adicione anotações que se refiram a `Incidents` e sua associação a `Customers`:

```cds
annotate service.Incidents with @(
  UI: {
    // insert table column
    LineItem : [
      ...up to { Value: title },
      { Value: customer.name, Label: 'Customer' },
      ...
    ],

    // insert customer to field group
    FieldGroup #GeneralInformation : {
      Data: [
        ...,
        { Value: customer_ID, Label: 'Customer'}
      ]
    },
  }
);

// for an incident's customer, show both name and ID
annotate service.Incidents:customer with @Common: {
  Text: customer.name,
  TextArrangement: #TextFirst
};
```

> Não altere as reticências `...` no código `cds` acima. É uma sintaxe especial para se referir aos 'valores restantes' de anotações com valores de array. A vantagem desta sintaxe é que você não precisa repetir as outras colunas da tabela. Consulte a [documentação](https://cap.cloud.sap/docs/cds/cdl#extend-array-annotations) para obter mais informações.

## Verifique na UI

👉 Agora clique no link `/incidents/webapp/index.html` na página de índice.
Este arquivo faz parte do aplicativo SAP Fiori Elements na pasta `app/incidents/webapp/`.

![](assets/fiori-app-html.png)

> Para obter mais informações sobre os elementos SAP Fiori, consulte [sessão AD161 - Construir aplicativos Full-Stack com ferramentas de código de construção SAP](https://github.com/SAP-samples/teched2023-AD161/blob/main/exercises/Ex7/README .md). Lá, você também pode aprender sobre as ferramentas dedicadas para anotações da UI. Você não precisa digitá-los manualmente.

👉 **Crie um novo incidente** e **selecione um cliente** usando a ajuda de valor. Ao pressionar _Salvar_, observe a saída do console do aplicativo e veja a mensagem `>> delegando ao serviço S4...`.

## Resumo

Você adicionou recursos básicos para chamar um serviço remoto.

Continue para o [exercício 3](../ex3/README.md) para ver como isso pode ser aprimorado.