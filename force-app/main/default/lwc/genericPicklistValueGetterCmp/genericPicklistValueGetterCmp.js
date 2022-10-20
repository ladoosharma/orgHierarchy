import { api, LightningElement, track, wire } from 'lwc';
import { getPicklistValues, getPicklistValuesByRecordType, getObjectInfo } from 'lightning/uiObjectInfoApi';
export default class GenericPicklistValueGetterCmp extends LightningElement {
    @api
    picklistField;
    @track
    picklistFieldObj;
    @api
    objectApiName;
    @track
    objectApiNameAll;
    @track
    recordTypeId;
    listOfPicklistValues;
    @api
    fieldLabel;
    @api
    recordTypeName;
    connectedCallback(){
        if(this.picklistField ){
            //we need to fetch specefic field and relay data
            this.picklistFieldObj = JSON.parse(this.picklistField);
        }else if(!this.picklistField && this.objectApiName ){
            this.objectApiNameAll = this.objectApiName;
        }
    }
    @api
    updateFieldName(picklistFieldObj){
        if(picklistFieldObj){
            this.picklistFieldObj = JSON.parse(picklistFieldObj);
            this.objectApiNameAll = '';
        }else{
            this.picklistFieldObj ={};
        }
    }
    /**
     * This method will fetch specefic picklist value based on record type
     * @param {*} param0 
     */
    @wire(getPicklistValues, { recordTypeId: '$recordTypeId', fieldApiName: '$picklistFieldObj' })
    picklistBasedOnRecordType({data, error}){
        
        if(data){
            this.dispatchEvent(new CustomEvent('singlepicklistfetched', { detail: data }));
        }else if(error){
            console.log(error);
        }
    }
    /**
     * This wired method will be called for fecthing all picklist value for an object 
     * @param {String} param object Api name for which we need to retriev all picklist value
     */
    @wire(getPicklistValuesByRecordType, {  objectApiName: '$objectApiNameAll', recordTypeId:'$recordTypeId' })
    allPicklistBasedOnField({data, error}){
            //fire and send all pciklist list
            if(data){
                console.log('allPicklist '+data);
                this.dispatchEvent(new CustomEvent('allpicklistfetched', { detail: data }));
            }else if(error){
                console.log(error);
            }
    }
    @wire(getObjectInfo, {objectApiName: '$objectApiName'})
    objectInfoForRecType({data, error}){
        if(data){
            this.recordTypeId = Object.keys(data.recordTypeInfos).find((eachId)=>{
                if(data.recordTypeInfos[eachId].name === this.recordTypeName && data.recordTypeInfos[eachId].available){
                    return true;
                }else if(!this.recordTypeName && data.recordTypeInfos[eachId].defaultRecordTypeMapping){
                    return true;
                }else{
                    return false;
                }
            });
            console.log('objectInfo '+data);
            
        }
        if(error){
            //handle error
            console.debug(error);
        }
    }
}