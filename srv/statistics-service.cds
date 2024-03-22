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