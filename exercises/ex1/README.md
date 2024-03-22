# Exercício 1 - Introdução ao CAP

Neste exercício, você construirá um pequeno aplicativo com SAP Cloud Application Programming Model (CAP).

Você usará esse cenário de aplicação ao longo dos exercícios.
Além disso, você se familiarizará com o CAP e a linguagem CDS.

O modelo de domínio conceitual para esta aplicação _Gerenciamento de Incidentes_ é o seguinte:

- *Clientes* podem criar *Incidentes* (diretamente ou por meio de agentes)
- *Incidentes* têm título, status e nível de urgência
- *Incidentes* contêm um histórico de *Conversa* composto por diversas mensagens

<p>

![Modelo de domínio](assets/domain.drawio.svg)


## Crie um projeto

👉 No SAP Business Application Studio, crie um novo _CAP Project_ por meio do assistente de projeto.
- Nomeie-o como `incidents-mgt`, por exemplo.
- Aceite o restante dos padrões. Nenhum código de amostra é necessário; você preencherá o projeto conforme avança.

<details>
<summary>Estas capturas de tela ajudam você a encontrar o assistente do projeto:</summary>

![Novo Projeto CAP](assets/BAS-NewProject.png)

![Novo projeto CAP - Detalhes](assets/BAS-NewProject-Details.png)

</details>
<p>

> Você também pode criar o projeto com `cds init incidents-mgt` na linha de comando na pasta `/home/user/projects`.

## Adicionar incidentes

Agora você deveria ter mudado para um novo espaço de trabalho com o projeto criado.

👉 Abra o explorador de arquivos novamente.

👉 Crie um arquivo `data-model.cds` na pasta `db`.
- Lá, adicione uma [entidade] `Incidents` (https://cap.cloud.sap/docs/cds/cdl#entities) com um campo-chave `ID` e um `title`.
- Escolha os tipos de dados apropriados. Use o preenchimento de código (intellisense) para escolher um tipo de dados adequado.
- Além disso, adicione um namespace `incidents.mgt` ao início do arquivo, para que o nome completo da entidade seja `incidents.mgt.Incidents`

<details>
<summary>É assim que deveria ser:</summary>

```cds
namespace incidents.mgt;

entity Incidents {
  key ID       : UUID;
  title        : String;
}
```
</details>

## Use aspectos predefinidos

A situação dos campos-chave `ID` é tão comum que existe um aspecto CDS pré-construído disponível chamado [`cuid`](https://cap.cloud.sap/docs/cds/common#aspect-cuid) que fornece exatamente isso .<br>
Ele pode ser importado com `using ... from '@sap/cds/common';` e usado em uma entidade com a sintaxe `:` (dois pontos).

Além disso, a entidade `Incidents` deverá conter informações sobre quando foi criada e atualizada e por quem. Existe um [aspecto `managed` de `@sap/cds/common`](https://cap.cloud.sap/docs/cds/common#aspect-owned) que faz isso.

👉 Faça uso dos dois aspectos e:
- Substitua o campo `ID` criado manualmente por [`cuid`](https://cap.cloud.sap/docs/cds/common#aspect-cuid)<br>
- Adicione o aspecto [`managed`](https://cap.cloud.sap/docs/cds/common#aspect-owned).


<details>
<summary>É assim que deveria ser:</summary>

```cds
using { cuid, managed } from '@sap/cds/common';

namespace incidents.mgt;

entity Incidents : cuid, managed {
  title        : String;
}
```
</details>

<p>

👉 Reserve alguns momentos e confira o que o pacote `@sap/cds/common` tem a oferecer adicionalmente. No editor, segure <kbd>Ctrl</kbd> (ou <kbd>⌘</kbd>) e passe o mouse sobre o texto `managed`. Clique para navegar por dentro.
Consulte a [documentação](https://cap.cloud.sap/docs/cds/common) para saber mais.


## Adicione um histórico de conversa

Um incidente deve conter uma série de mensagens para construir um histórico de conversação.

Para criar esse relacionamento, o **modelador gráfico de CDS** no SAP Business Application Studio é uma ótima ferramenta.<br>
👉 Abra-o para o arquivo `data-model.cds` usando uma das duas opções:
- Clique com o botão direito no arquivo `data-model.cds`. Selecione `Abrir com` > `Modelador gráfico CDS`
- Ou abra o modelador através do projeto **Storyboard**:
   - Pressione <kbd>F1</kbd> > `Abrir Storyboard`
   - Clique na entidade `Incidents` > `Abrir no Modelador Gráfico`

👉 Em sua tela, adicione uma entidade `Conversas`.
- Na aba `Aspects` da folha de propriedades, adicione o campo-chave `ID` do aspecto CDS `cuid`.
- Adicione os campos `timestamp`, `author` e `message` com os tipos apropriados.

👉 Agora **conecte** as duas entidades.
- Passe o mouse sobre a entidade `Incidents` e encontre o botão `Adicionar Relacionamento` no menu suspenso. Arraste-o **de** `Incidents` **para** a entidade `Conversations`.
- Na caixa de diálogo `Novo Relacionamento`:
   - Escolha um tipo de relacionamento para que sempre que uma instância de `Incident` for excluída, todas as suas conversas também sejam excluídas.
   - Fique com os campos propostos de `conversations` e `incidents`.


<details>
<summary>Resumindo, as entidades ficarão assim:</summary>

![Entidades de incidentes e conversas no modelador gráfico](assets/Incidents-Conversations-graphical.png)

Como texto, fica assim. Observe a `Composição` entre as duas entidades.

```cds
using { cuid, managed } from '@sap/cds/common';

namespace incidents.mgt;

entity Incidents : cuid, managed {
  title         : String(100);
  conversations : Composition of many Conversations on conversations.incidents = $self;
}

entity Conversations : cuid, managed {
  timestamp : DateTime;
  author    : String(100);
  message   : String;
  incidents : Association to Incidents;
}
```

</details>

> Para abrir o editor de código, basta clicar duas vezes no arquivo `db/data-model.cds` na árvore do explorador.

<!-- > Nos exercícios a seguir, sinta-se à vontade para usar o modelador gráfico ou o editor de código como desejar. Descubra o que funciona para você.<br>
Porém nas soluções imprimiremos a forma textual, pois é mais conveniente copiar/colar. -->


## Adicionar status e urgência

Os incidentes deverão ter mais dois campos `status` e `urgency`, que são 'listas de códigos', ou seja, dados de configuração.

👉 Adicione duas entidades, usando o aspecto [`sap.common.CodeList`](https://cap.cloud.sap/docs/cds/common#aspect-codelist).
- `Status` para o status do incidente como _new_, _in process_ etc.
  - Nomeie seu campo-chave como `code` em vez de `ID`.
- `Urgency` para denotar a prioridade como _high_, _medium_ etc.
  - Nomeie seu campo-chave como `code` em vez de `ID`.

👉 Adicione uma [associação](https://cap.cloud.sap/docs/guides/domain-modeling#associations) a `Incidents` apontando para cada nova entidade. As associações devem ser apenas _unidirecionais_, ou seja, apontando _de_ `Incidents` para `Status` ou `Urgency`, mas não na outra direção.

<details>
<summary>Veja o resultado:</summary>

Em `db/data-model.cds`, adicione:

```cds
using { sap.common.CodeList } from '@sap/cds/common';

entity Status : CodeList {
  key code  : String;
}

entity Urgency : CodeList {
  key code : String;
}

entity Incidents {
  ...
  urgency       : Association to Urgency;
  status        : Association to Status;
};
```

</details>

## Crie um serviço CDS

Deve haver uma API para processadores de incidentes para manter incidentes.

👉 Em um novo arquivo `srv/processor-service.cds`, crie um [serviço CDS](https://cap.cloud.sap/docs/cds/cdl#service-definitions) que expõe um um para um projeção em `Incidents`.<br>

<details>
<summary>É assim que o serviço deveria ser:</summary>

```cds
using { incidents.mgt } from '../db/data-model';

service ProcessorService {

  entity Incidents as projection on mgt.Incidents;

}
```

</details>

## Inicie o aplicativo

👉 Execute o aplicativo:
- Abra um terminal. Pressione <kbd>F1</kbd>, digite _new terminal_ ou use o menu principal.
- No terminal, execute na pasta raiz do projeto:

   ```sh
    cds watch
   ```

   <details>
   <summary>Veja a saída do console:</summary>

   ![Iniciar aplicativo, saída do terminal](assets/StartApp-Terminal.png)
   </details>

   <p>

Reserve um momento e verifique o resultado do que está acontecendo:

- A aplicação consiste em três arquivos `cds`. Duas são fontes de aplicativos e uma vem da biblioteca `@sap/cds`:
  ```sh
  [cds] - loaded model from 3 file(s):

    srv/processor-service.cds
    db/data-model.cds
    .../@sap/cds/common.cds
  ```

- Um [banco de dados SQLite] na memória (https://cap.cloud.sap/docs/guides/databases-sqlite) foi criado. Ele contém os dados do aplicativo (que ainda não temos).
  ```sh
  [cds] - connect to db > sqlite { database: ':memory:' }
  /> successfully deployed to in-memory database.
  ```

- O serviço CDS foi exposto neste caminho:
  ```sh
  [cds] - serving ProcessorService { path: '/odata/v4/processor' }
  ```


👉 Agora <kbd>Ctrl+Clique</kbd> no link `http://localhost:4004` no terminal.
- No SAP Business Application Studio, esse URL é automaticamente transformado em um endereço como `https://port4004-workspaces-ws-...applicationstudio.cloud.sap/`
- Se você trabalha localmente, seria http://localhost:4004.

Na página de índice, todos os terminais são listados junto com as entidades que eles expõem.

![Página de índice com lista de endpoints e entidades](assets/IndexPage.png)

O link _Fiori preview_ você usará mais tarde.

👉 Você sabe por que o caminho da URL do serviço é `/processor`? Qual é o link `$metadata`?

<details>
<summary>Aqui está o porquê:</summary>

Você nomeou o serviço CDS como `ProcessorService`, e o sistema de tempo de execução infere a URL `processor` removendo `Service`. Você pode configurar isso explicitamente usando a [anotação `@path`](https://cap.cloud.sap/docs/node.js/cds-serve#path).

A URL `$metadata` fornece o documento de metadados necessário para o [protocolo OData](https://cap.cloud.sap/docs/advanced/odata). Em breve você verá o OData em ação.

</details>

## Adicionar dados de exemplo

Adicione alguns dados de teste para trabalhar.

👉 Crie **arquivos csv** vazios para todas as entidades. Em um novo terminal, execute:

```sh
cds add data
```


Assim que eles estiverem lá, o `cds watch` os localiza e os implanta no banco de dados. Verifique a saída do console:

```sh
[cds] - connect to db > sqlite { database: ':memory:' }
> init from db/data/incidents.mgt-Urgency.texts.csv
> init from db/data/incidents.mgt-Urgency.csv
> init from db/data/incidents.mgt-Status.texts.csv
> init from db/data/incidents.mgt-Status.csv
> init from db/data/incidents.mgt-Incidents.csv
> init from db/data/incidents.mgt-Conversations.csv
```

> Observe como os nomes dos arquivos correspondem aos nomes das entidades.

Agora preencha algum conteúdo:

👉 Para as duas listas de códigos, **adicione registros csv no terminal** bem rápido:

```sh
cat << EOF > db/data/incidents.mgt-Status.csv
code,name
N,New
I,In Process
C,Closed
EOF

cat << EOF > db/data/incidents.mgt-Urgency.csv
code,name
H,High
M,Medium
L,Low
EOF
```

👉 Para os arquivos csv `Incidents` e `Conversations`, use o **editor de dados de exemplo** para preencher alguns dados.
- Clique duas vezes no arquivo `db/data/incidents.mgt-Incidents.csv` na árvore do explorador.
- No editor, adicione talvez 10 linhas. Utilize o campo `Número de linhas` e clique em `Adicionar` para criar os registros.
- Crie também registros para o arquivo `db/data/incidents.mgt-Conversations`. O editor preenche automaticamente a chave estrangeira `incidents_ID`.

👉 Na página de índice dos aplicativos, clique no link `Incidents` que executa uma solicitação `GET /odata/v4/processor/Incidents`.<br>


## Adicione uma UI simples

👉 Clique em _Incidents_ > _[Fiori Preview](https://cap.cloud.sap/docs/advanced/fiori#sap-fiori-preview)_ na página de índice da aplicação. Isso abre um aplicativo SAP Fiori Elements que foi criado dinamicamente. Ele exibe os dados da entidade em uma lista.

A lista parece estar vazia embora existam dados disponíveis. Isso ocorre porque nenhuma coluna está configurada. Vamos mudar isso.

👉 Adicione um arquivo `app/annotations.cds` com este conteúdo:

```cds
using { ProcessorService as service } from '../srv/processor-service';

// enable drafts for editing in the UI
annotate service.Incidents with @odata.draft.enabled;

// table columns in the list
annotate service.Incidents with @UI : {
  LineItem  : [
    { $Type : 'UI.DataField', Value : title},
    { $Type : 'UI.DataField', Value : modifiedAt },
    { $Type : 'UI.DataField', Value : status.name, Label: 'Status' },
    { $Type : 'UI.DataField', Value : urgency.name, Label: 'Urgency' },
  ],
};

// title in object page
annotate service.Incidents with @(
    UI.HeaderInfo : {
      Title : {
        $Type : 'UI.DataField',
        Value : title,
      },
      TypeName : 'Incident',
      TypeNamePlural : 'Incidents',
      TypeImageUrl : 'sap-icon://alert',
    }
);
```

que cria 3 colunas:

![Página da lista Fiori com 3 colunas](assets/Fiori-simple.png)

Existe até um rótulo pré-configurado para a coluna `modifiedAt`.<br>
👉 Você sabe como procurá-los? Dica: use os recursos do editor.

<details>
<summary>Veja como:</summary>

No aspecto `managed` em `db/data-model.cds`, selecione _Ir para Referências_ no menu de contexto. Expanda `common.cds` na árvore à direita e verifique as entradas `annotate managed` até ver as anotações `@title`:

![Diálogo com todas as referências do aspecto gerenciado](assets/Editor-GoToReferences.png)

Os textos atuais são obtidos de um pacote de recursos que é endereçado com uma chave `{i18n>...}`. Consulte o [guia de localização](https://cap.cloud.sap/docs/guides/i18n) para saber como isso funciona.

</details>

<p>

O rótulo da coluna `title` parece estar errado.<br>
👉 Corrija-o adicionando a [anotação CDS](https://cap.cloud.sap/docs/advanced/fiori#prefer-title-and-description) apropriada ao elemento `Incidents.title`.

<details>
<summary>É assim que você pode fazer isso:</summary>

Adicione uma anotação `@title:'Title'` à definição de `Incidents`. Certifique-se de colocá-lo corretamente antes do ponto e vírgula. Cuidado com erros de sintaxe.

```cds
entity Incidents : cuid, managed {
  title         : String(100) @title : 'Title';   // <--
  ...
}
```

Observe que as anotações podem ser adicionadas em [locais diferentes na sintaxe do CDS](https://cap.cloud.sap/docs/cds/cdl#annotations).

</details>

## Adicionar lógica de negócios

Vamos adicionar um pouco de lógica ao aplicativo. Quando um incidente é criado com _urgent_ no título, sua urgência deve ser definida como 'Alta'.

👉 Adicione um arquivo `srv/processor-service.js` com este conteúdo:

```js
const cds = require('@sap/cds')

class ProcessorService extends cds.ApplicationService {
  async init() {

    this.before('CREATE', 'Incidents', ({ data }) => {
      if (data) {
        const incidents = Array.isArray(data) ? data : [data]
        incidents.forEach(incident => {
          // TODO add code here
        })
      }
    })

    return super.init()
  }
}

module.exports = ProcessorService
```

Observe como o arquivo `js` tem o mesmo nome do arquivo `cds`. É assim que a estrutura encontra a implementação. Você pode ver isso na saída de `cds watch`, onde ele imprime o valor `impl`:

```sh
...
[cds] - serving ProcessorService { path: '/odata/v4/processor', impl: 'srv/processor-service.js' }
...
```

> Não vê o arquivo `js` listado lá? Verifique a ortografia!

👉 Complete o código com a lógica real: verifique se o `title` inclui `urgent` e nesse caso defina seu `urgency code` para `H`.
- Trate `urgent` e `Urgent` da mesma maneira.
- Também seja robusto caso não haja título atribuído.

<details>
<summary>Solução:</summary>

```js
          if (incident.title?.toLowerCase().includes('urgent')) {
            incident.urgency = { code: 'H' }
          }
```
</details>

<p>

👉 Agora teste a lógica criando um incidente por meio da UI. Adicione a palavra _urgent_ no título. Depois de salvá-lo, volte para a lista. Você deverá ver a urgência definida como _High_.

## Depure o código (opcional)

Se você deseja depurar o código usando o depurador visual Javascript integrado, faça o seguinte:
- Elimine o processo `cds watch` em execução.
- Pressione <kbd>F1</kbd>, digite _debug terminal_, selecione _Javascript: Debug Terminal_
- Neste terminal, inicie `cds watch` normalmente. O depurador é iniciado e anexado a esse processo.
- Na parte superior, no meio da janela, veja o painel flutuante com o qual você pode controlar o depurador e realizar operações passo a passo.<br>
   ![Controles do depurador](assets/DebuggerControls.png)
- Defina um ponto de interrupção na fonte dentro da função `this.before(...`. Faça isso clicando duas vezes ao lado do número da linha.<br>
   <details>
   <summary>Pergunta rápida: nesta situação, por que o depurador não pararia fora desta função?</summary>

   Porque a função `before()` é um [manipulador de solicitação](https://cap.cloud.sap/docs/node.js/core-services#srv-on-before-after), e é apenas esse tipo de solicitação- lidar com código que pode ser depurado agora.<br>
   O código acima e abaixo é um código [bootstrap](https://cap.cloud.sap/docs/node.js/cds-server) que só pode ser depurado se você definir o ponto de interrupção anteriormente ou fazer o depurador parar logo quando o processo do servidor é iniciado.
   </details>
- Agora crie um novo incidente. A UI congela porque o depurador foi interrompido.
- Para variáveis, pressione <kbd>F1</kbd>, digite _variables_, selecione _Run and Debug: Focus on Variables View_.
- Depois de inspecionar as variáveis, não se esqueça de continuar a execução usando o painel de controle de depuração, caso contrário a UI do aplicativo não reagirá (e eventualmente atingirá o tempo limite).

## Adicionar outro serviço

No serviço acima, você usou apenas a forma mínima de uma [projeção CDS](https://cap.cloud.sap/docs/cds/cdl#views-and-projections), que basicamente faz uma exposição de uma entidade à superfície da API:

```cds
service ProcessorService {
  entity Incidents as projection on mgt.Incidents;
}
```

No entanto, as projeções vão muito além disso e fornecem meios poderosos para expressar consultas para cenários de aplicação específicos.
- Quando mapeadas para bancos de dados relacionais, tais projeções são de fato traduzidas para visualizações SQL.
- Em breve você verá usos de projeções não pertencentes ao banco de dados.

👉 Agora explore projeções e serviços. Adicione um 'serviço de estatísticas' que mostre
- `Title` dos incidentes
- Seu `status`, mas mostrando `New` em vez de `N` etc. Dica: use uma [expressão de caminho](https://cap.cloud.sap/docs/cds/cql#path-expressions) para o `name`.
- Apenas incidentes urgentes. Dica: use uma [condição `where`](https://cap.cloud.sap/docs/cds/cql).

O resultado estará disponível em `/odata/v4/statistics/UrgentIncidents`. Qual é o nome do serviço CDS que corresponde a este URL?

Além disso, use o preenchimento de código do editor que o orienta ao longo da sintaxe.<br>

<details>
<summary>Solução:</summary>

Em um arquivo `srv/statistics-service.cds` separado, adicione isto:

```cds
using { incidents.mgt } from '../db/data-model';

service StatisticsService {

  entity UrgentIncidents as projection on mgt.Incidents {
    title,                  // expose as-is
    status.name as status,  // expose with alias name using a path expression
  }
  where urgency.code = 'H'  // filter
}
```
</details>

<p>

👉 Se você conseguiu isso, adicione estes campos com sintaxe mais avançada:
- `modified` : uma string concatenada de `modifiedAt` e `modifiedBy` (use a sintaxe `str1 || str2`)
- `conversationCount` : uma contagem do número de mensagens de conversa. Dica: SQL tem uma função `count()`. Não se esqueça da cláusula `group by`.

<details>
<summary>Solução:</summary>

```cds
using { incidents.mgt } from '../db/data-model';

service StatisticsService {

  entity UrgentIncidents as projection on mgt.Incidents {
    title,                  // expose as-is
    status.name as status,  // expose with alias name using a path expression

    modifiedAt || ' (' || modifiedBy || ')' as modified          : String,
    count(conversations.ID)                 as conversationCount : Integer
  }
  where urgency.code = 'H' // filter
  group by ID              // needed for count()
}
```
</details>

<p>

Verifique em `/odata/v4/statistics/UrgentIncidents` os resultados. Observe que eles irão variar dependendo dos dados da sua amostra.

Lembre-se: você tem todo esse poder sem uma única linha de código (Javascript ou Java)!

## Testar recursos OData (opcional)

Vamos inspecionar alguns dos recursos integrados do [OData](https://cap.cloud.sap/docs/advanced/odata).

👉 No navegador, anexe ao URL do serviço `.../odata/v4/processor/Incidents` para que você possa:
- listar incidentes
- com suas mensagens de conversa,
- limitar a lista a `5` entradas,
- mostrando apenas o campo `title`,
- classificando em ordem alfabética ao longo do `title`

Como você pode fazer isso usando opções de consulta do [OData](https://cap.cloud.sap/docs/advanced/odata) como `$expand` etc.?
<details>
<summary>É assim:</summary>

Adicionar
```
?$select=title&$orderby=title&$top=5&$expand=conversations
```

para o URL.

</details>

## Inspecione o banco de dados (opcional)

Após a implantação no banco de dados, o CAP cria instruções SQL DDL para criar tabelas e visualizações para suas entidades.

👉 No arquivo `db/data-model.cds`, selecione `CDS Preview > Preview as sql` no menu de contexto do editor. Isso abre um painel lateral com as instruções SQL.

<details>
<summary>Veja como fica:</summary>

![Visualização SQL para modelo de dados](assets/PreviewAsSQL.png)

</details>

<p>

👉 Você pode fazer o mesmo no terminal com
```sh
cds compile db --to sql
```

👉 Agora faça o mesmo no arquivo `srv/statistics-service.cds`. O que há de diferente no resultado? Você pode explicar de onde vêm as novas instruções SQL?

<details>
<summary>É por isso:</summary>

Para cada projeção CDS, é criada uma visualização SQL que captura as consultas das projeções. É por isso que você vê muito mais instruções `CREATE VIEW`.

</details>

## Resumo

Agora você criou uma versão básica do aplicativo de gerenciamento de incidentes. Ainda assim, é muito poderoso porque:

- Expõe **APIs ricas** e metadados OData. Você verá clientes OData como SAP Fiori Elements UI em breve.
- Implanta em um **banco de dados pronto para uso**, incl. arquivos de dados.
- Vamos manter **concentrado no modelo de domínio** sem a necessidade de escrever código imperativo para solicitações CRUD simples.
- Mantém **arquivos padrão ao mínimo**. Basta contar os poucos arquivos do projeto.

Agora continue para o [exercício 2](../ex2/README.md), onde você estenderá o aplicativo com recursos remotos.