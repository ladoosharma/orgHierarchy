import {
    LightningElement,
    api,
    wire,
    track
} from 'lwc';
import fetchObjectHierarchy from '@salesforce/apex/fetchHierarchyData.fetchObjectHierarchy';
import getFieldDefinition from '@salesforce/apex/fetchHierarchyData.getFieldDefinition';
export default class RenderHierarchyCmp extends LightningElement {
    @api objectName;
    @api parentRelationShipName;
    @api fieldToBeQueried;
    @api sortingOnFields;
    @api recordId;
    @track hierarchyObject;
    @track hierarchyList;
    @track fieldList;
    @track fieldsProperty;
    branchIndexNo;
    branchDepth;
    @wire(fetchObjectHierarchy, {
        objName: '$objectName',
        hierarchyField: '$parentRelationShipName',
        fieldsToBeFetched: '$fieldToBeQueried',
        currentObjectRecordId: '$recordId',
        whereCauseForHeirarchy: ''
    })
    hierarchyValue({
        data,
        error
    }) {
        if(data){
            this.hierarchyObject = data;
            this.fieldList = this.fieldToBeQueried.split(',');
        }
        if(error){
            console.error(error);
        }
    }
    @wire(getFieldDefinition, {fields:'$fieldList', objectName:'$objectName'})
    fieldDefinition({data, error}){
        if(data){
            //generate table
            this.fieldsProperty = data.map((eachCol)=>{
                return Object.assign({isReference: eachCol.dataType==='REFERENCE'}, eachCol);
            });
            this.generateInitialTable();
        }
        if(error){
            console.error(error);
        }
    }
    generateInitialTable(){
        if(this.hierarchyObject){
            const branchIndex = getBranchIndex(this.hierarchyObject);
            
        }
    }
    getBranchIndex(node, indexNo){
        if(node.currentObj){
            this.indexNo = indexNo?indexNo:0;
        }
        if(node.belowNode){
            node.belowNode.forEach((eachNode,indx)=>{
                this.getBranchIndex(eachNode, (indexNo)?indexNo:indx );
            });
        }
    }
    searchForItemRecorsively(){

    }
    addingDummyMethod(){

    }
    addingDummyMethodForCommit2(){
        //adding extra lines
    }
}