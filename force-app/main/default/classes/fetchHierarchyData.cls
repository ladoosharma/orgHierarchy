public with sharing class fetchHierarchyData {
    private static Map<Id,List<sObject>> parentToImmediateChildMap;
    private static  Map<Id, sObject> allObject;
    @AuraEnabled(cacheable=true)
    public static List<FieldWrapp> getFieldDefinition(List<String> fields, String objectName){
        try {
            if(fields.isEmpty() || String.isBlank(objectName)){
                throw new AuraHandledException('Object Name or field list cannot be empty.');
            }
            Schema.SObjectType sobjType = Schema.getGlobalDescribe().get(objectName);
            Map<String, Schema.SObjectField> fieldMap = sobjType.getDescribe().fields.getMap();
            List<FieldWrapp> returnWrapp = new List<FieldWrapp>();
            for(String field: fields){
                if(fieldMap.containsKey(field)){
                    Schema.DescribeFieldResult fieldResult = fieldMap.get(field).getDescribe();
                    FieldWrapp eachFieldDef = new FieldWrapp();
                    eachFieldDef.dataType = String.valueOf(fieldResult.type);
                    eachFieldDef.fieldApiName = field;
                    eachFieldDef.fieldLabel = fieldResult.label;
                    returnWrapp.add(eachFieldDef);
                }
            }
            return returnWrapp;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    @AuraEnabled(cacheable=true)
    public static HierarchyWrapper fetchObjectHierarchy(String objName, String hierarchyField, String fieldsToBeFetched, Id currentObjectRecordId, String whereCauseForHeirarchy){
        try {
            Long startTime = System.now().getTime();
            if(String.isBlank(objName) || String.isBlank(hierarchyField) || String.isBlank(currentObjectRecordId)){
                throw new AuraHandledException('Object API Name or Heiaracy fields or record ID cannot be blank.');
            }
            Schema.SObjectType sobjType = Schema.getGlobalDescribe().get(objName);
            if(currentObjectRecordId.getSobjectType() === sobjType){
                List<String> fieldToBefetchedList = new List<String>();
                List<FieldWrapp> allFields = getFieldDefinition(fieldsToBeFetched.split(','), objName);
                for(FieldWrapp wrap: allFields){
                    if(wrap.dataType == 'REFERENCE'){
                        fieldToBefetchedList.add((wrap.fieldApiName.endsWithIgnoreCase('__c'))?wrap.fieldApiName.replace('__c', '__r')+'.Name':(wrap.fieldApiName.endsWithIgnoreCase('Id'))?wrap.fieldApiName.substringBeforeLast('Id')+'.Name':wrap.fieldApiName);
                    }else if(wrap.dataType == 'PICKLIST'){
                        fieldToBefetchedList.add('toLabel($)'.replace('$', wrap.fieldApiName));
                    }else{
                        fieldToBefetchedList.add(wrap.fieldApiName);
                    }
                }
                allObject= new Map<Id,sobject>(Database.query('SELECT Id, '+hierarchyField+','+ String.join(fieldToBefetchedList, ',')+ ' FROM '+ objName +' LIMIT 49999'));
                parentToImmediateChildMap= new Map<Id,List<sObject>>();
                for(sObject tempSObj: allObject.values()){
                    if(tempSObj.isSet(hierarchyField)){
                        if(tempSObj.get(hierarchyField) != null && parentToImmediateChildMap.containsKey((Id)tempSObj.get(hierarchyField))){
                            parentToImmediateChildMap.get((Id)tempSObj.get(hierarchyField)).add(tempSObj);
                        }else if(tempSObj.get(hierarchyField) != null){
                            parentToImmediateChildMap.put((Id)tempSObj.get(hierarchyField), new List<sObject>{tempSObj});
                        }else if(tempSObj.get(hierarchyField) == null){
                            parentToImmediateChildMap.put((Id)tempSObj.get('Id'), new List<sObject>());
                        }
                    }else{
                        parentToImmediateChildMap.put((Id)tempSObj.get('Id'), new List<sObject>());
                    }
                }
                if(!parentToImmediateChildMap.isEmpty()){
                    Boolean whileCondition = true;
                    String topParent = currentObjectRecordId;
                    while (whileCondition) {
                        String tempParent = getAboveLevelHierarchy(topParent, hierarchyField);
                        topParent = (tempParent != null)?tempParent:topParent;
                        Long executionTimeLimit = System.now().getTime();
                        if(tempParent == null){
                            whileCondition = false;
                        }else if(executionTimeLimit - startTime == 10000){
                            whileCondition = false;
                            throw new AuraHandledException('Heierarchy too big to extract , use standard hiererchy to view the data.');
                        }
                    }
                    if(!String.isBlank(topParent)){
                        if(parentToImmediateChildMap.containsKey(topParent)){
                            return wrapperObjectGenererator(topParent, currentObjectRecordId);
                        }
                    }
                }
            }else{
                throw new AuraHandledException('Record Id doesnt match the sobject name being retrieved');
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
        return null;
    }

    private static String getAboveLevelHierarchy(Id immediateParent, String parentField){
        String tempParent;
        if(!parentToImmediateChildMap.isEmpty()){
            for(Id objTemId: parentToImmediateChildMap.keySet()){
                for(sObject sobj: parentToImmediateChildMap.get(objTemId)){
                    if(String.valueOf(sobj.get('Id')) == immediateParent){
                        tempParent = objTemId;
                        break;
                    }
                }
            }
            return tempParent;
        }
        return null;
    }
    private static HierarchyWrapper wrapperObjectGenererator(Id topLevelParent, Id currentSelectedObj){
        HierarchyWrapper parentWrapp = new HierarchyWrapper();
        if(!String.isBlank(topLevelParent) && !String.isBlank(currentSelectedObj)){         
            parentWrapp.nodeId = topLevelParent;
            parentWrapp.nodeObject = allObject.get(topLevelParent);
            parentWrapp.currentObj = (topLevelParent == currentSelectedObj);
            parentWrapp.belowNode = createIterativeObj(topLevelParent, currentSelectedObj);
        }
        return parentWrapp;
    }
    private static List<HierarchyWrapper> createIterativeObj(Id parentId, String currentId){
        List<HierarchyWrapper> wrappList = new List<HierarchyWrapper>();
        for(sobject sobj: parentToImmediateChildMap.get(parentId)){
            HierarchyWrapper tempWrapp = new HierarchyWrapper();
            tempWrapp.nodeId = (Id)sobj.get('Id');
            tempWrapp.nodeObject = allObject.get((Id)sobj.get('Id'));
            tempWrapp.currentObj = (Id)sobj.get('Id') == currentId;
            if(parentToImmediateChildMap.containsKey((Id)sobj.get('Id'))){
                tempWrapp.belowNode = createIterativeObj((Id)sobj.get('Id'), currentId);
            }
            wrappList.add(tempWrapp);
        }
        return wrappList;
    }
    public class HierarchyWrapper{
        @auraenabled 
        public Id nodeId;
        @auraenabled 
        public sObject nodeObject;
        @auraenabled 
        public Boolean currentObj;
        @auraenabled 
        public List<HierarchyWrapper> belowNode;
    }
    public class FieldWrapp{
        @auraenabled 
        public String fieldApiName;
        @auraenabled 
        public String fieldLabel;
        @auraenabled 
        public String dataType;
    }
}