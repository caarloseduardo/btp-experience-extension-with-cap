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