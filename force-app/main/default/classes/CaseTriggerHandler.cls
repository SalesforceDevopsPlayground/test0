/**
*   Class for automatic updating fields on the case object.
*   @Author Nikita Phutane
*   @Company Accenture
*   @Date 03.05.2019
*   @test-class @see CaseTriggerHandler_Test
* <p style="color:green;">CLEANED 27.05.2021.</p>
*/
public class CaseTriggerHandler {

    public static final String CASE_STATUS_IN_PROGRESS_2ND_LINE = 'In Progress 2nd Line';
    public static final String CASE_STATUS_IN_PROGRESS = 'In Progress';
    public static final String PROFILE_NAME_CUSTOMER_CARE_AGENT_2ND_LINE = 'Customer Care Agent 2nd Line';
    private static final Id PROFILE_ID_CUSTOMER_CARE_AGENT_2ND_LINE {
        get {
            if (PROFILE_ID_CUSTOMER_CARE_AGENT_2ND_LINE == null) {
                List<Profile> profiles = [SELECT Id FROM Profile WHERE Name = :PROFILE_NAME_CUSTOMER_CARE_AGENT_2ND_LINE LIMIT 1];
                PROFILE_ID_CUSTOMER_CARE_AGENT_2ND_LINE = (profiles.size() == 1) ? profiles.get(0).Id : null;
            }
            return PROFILE_ID_CUSTOMER_CARE_AGENT_2ND_LINE;
        }
        set;
    }
    private static UtilityRegexHandler.SSNRegexHandler ssnRegexHandler {
        get {
            if (ssnRegexHandler == null) {
                ssnRegexHandler = new UtilityRegexHandler.SSNRegexHandler();
            }
            return ssnRegexHandler;
        }
        set;
    }

    /**
    * @description Method to link create a list of assets and Accounts and update the relations if there is a change in them.
    * @author Nikita Phutane
    * @date 03.06.2019
    * @param CaseList,OldCaseMap,newCaseMap from trigger
     * @param oldCaseMap NOT DOC'ED.
    **/
    public static void setCaseToAssetAndAccountRelations(List<Case> caseList, Map<Id, Case> oldCaseMap) {
        Set<Id> setAssetIds = new Set<Id>();
        Set<Id> setAccountIds = new Set<Id>();
        List<Case> listCasesWithAssetLinked = new List<Case>();
        List<Case> listCasesWithAccountLinked = new List<Case>();

        for (Case aCase : caseList) {
            Case oldCase = oldCaseMap != null ? oldCaseMap.get(aCase.Id) : null;
            if ((aCase.AssetId != null && (oldCase == null || oldCase.AssetId != aCase.AssetId))) {
                setAssetIds.add(aCase.AssetId);
                listCasesWithAssetLinked.add(aCase);
            }

            else if (aCase.AccountId != null && (oldCase == null || oldCase.AccountId != aCase.AccountId)) {
                setAccountIds.add(aCase.AccountId);
                listCasesWithAccountLinked.add(aCase);
            }
        }

        if (listCasesWithAssetLinked != null && listCasesWithAssetLinked.size() > 0) {
            linkCaseToAssetRelations(setAssetIds, listCasesWithAssetLinked);
        }

        if (listCasesWithAccountLinked != null && listCasesWithAccountLinked.size() > 0) {
            linkCaseToAccountRelations(setAccountIds, listCasesWithAccountLinked);
        }
    }

    /**
    * @description Method for linking case to CPR related relations - CPR party,CPR asset
    * @author Nikita Phutane
    * @date 03.06.2019
    * @param CaseList,oldCaseMap from trigger
     * @param oldCaseMap NOT DONE.
   **/
    public static void setCaseToCPRRelations(List<Case> caseList, Map<Id, Case> oldCaseMap) {
        Set<Id> contactIdSet = new Set<Id>();
        List<Case> listCasesWithCPRChange = new List<Case>();
        Map<Id, Customer_Product_Role__c> cPRIdAndCPRMap = new Map<Id, Customer_Product_Role__c>();

        for (Case aCase : caseList) {
            Case oldCase = oldCaseMap != null ? oldCaseMap.get(aCase.Id) : null;
            if (aCase.Customer_Product_Role__c != null && (oldCase == null || (oldCase.Customer_Product_Role__c != aCase.Customer_Product_Role__c))) {
                contactIdSet.add(aCase.Customer_Product_Role__c);
                listCasesWithCPRChange.add(aCase);
            }
        }

        if (contactIdSet.size() > 0) {
            List <Customer_Product_Role__c> CPRList = [SELECT Id, Party__c, asset__c FROM Customer_Product_Role__c WHERE Id IN :contactIdSet];

            for (Customer_Product_Role__c aCpr : CPRList) {
                cPRIdAndCPRMap.put(aCpr.Id, aCpr);
            }

            for (Case aCase : listCasesWithCPRChange) {
                for (Customer_Product_Role__c con : CPRList) {
                    if (cPRIdAndCPRMap.containsKey(aCase.Customer_Product_Role__c)) {
                        Customer_Product_Role__c tempCRP = cPRIdAndCPRMap.get(aCase.Customer_Product_Role__c);
                        if (aCase.AssetId == null) {
                            aCase.AssetId = tempCRP.asset__c;
                        }
                    }
                }
            }
        }
    }

    /**
   * @description: If Asset is linked to the Case, associate to asset relations.
   * @author :Nikita Phutane
   * @date  :14.06.2019
   * @param setAssetIds Set of AssetIds,List of cases
   * @param caseList NOT DONE.
  **/
    public static void linkCaseToAssetRelations(Set<Id> setAssetIds, List<Case> caseList) {
        Map<Id, List<Customer_Product_Role__c>> assetCPRtMap = new Map<Id, List<Customer_Product_Role__c>>();
        Map<Id, Asset> assetIdAndAssetMap = new Map<Id, Asset>();
        Set<Id> setAccountIds = new Set<Id>();
        List<Case> listCasesWithAccountLinked = new List<Case>();
        List <Asset> assetList = [
                SELECT Id, AccountId, Brand__c, (SELECT Id, Party__c FROM Customer_Product_Roles__r)
                FROM Asset
                WHERE Id IN :setAssetIds
        ];

        for (Asset aAsset : assetList) {
            assetIdAndAssetMap.put(aAsset.Id, aAsset);
            if (aAsset.Customer_Product_Roles__r != null) {
                assetCPRtMap.put(aAsset.Id, aAsset.Customer_Product_Roles__r);
            }
        }

        for (Case aCase : caseList) {
            if (assetIdAndAssetMap.containsKey(aCase.AssetId)) {

                aCase.AccountId = assetIdAndAssetMap.get(aCase.AssetId).AccountId;
                setAccountIds.add(aCase.AccountId);

                if (assetCPRtMap.containsKey(aCase.AssetId)) {
                    List<Customer_Product_Role__c> TempCPRList = assetCPRtMap.get(aCase.AssetId);

                    if (aCase.Customer_Product_Role__c == null && TempCPRList != null && TempCPRList.size() == 1) {
                        aCase.Customer_Product_Role__c = TempCPRList.get(0).Id;
                        if (TempCPRList.get(0).Party__c != null) {
                        }
                    }
                }
                listCasesWithAccountLinked.add(aCase);
            }
        }

        if (listCasesWithAccountLinked != null && listCasesWithAccountLinked.size() > 0) {
            linkCaseToAccountRelations(setAccountIds, listCasesWithAccountLinked);
        }
    }

    /**
  * @description: If Account is linked to the Case associate to account relations - party of legal owner.
  * @author :Nikita Phutane
  * @date  :14.06.2019
  * @param setAccountIds Set of AccountIds,List of cases
  * @param caseList NOT DONE:
 **/
    public static void linkCaseToAccountRelations(Set<Id> setAccountIds, List<Case> caseList) {
        List<Account> accountRoleList = [
                SELECT Id, AccountNumber, (
                        SELECT Id,Brand__c,Party__c,Role_Type__c
                        FROM Account_Roles__r
                )
                FROM Account
                WHERE Id IN :setAccountIds
        ];

        Map<Id, List<Account_Role__c>> accountIdAndAccountRoleMap = new Map<Id, List<Account_Role__c>> ();
        for (Account aAccount : accountRoleList) {
            if (aAccount.Account_Roles__r != null) {
                accountIdAndAccountRoleMap.put(aAccount.Id, aAccount.Account_Roles__r);
            }
        }

        for (Case aCase : caseList) {
            if (accountIdAndAccountRoleMap.containsKey(aCase.AccountId)) {
                List<Account_Role__c> tempARList = accountIdAndAccountRoleMap.get(aCase.AccountId);
                if (tempARList != null && tempARList.size() == 2) {
                    for (Account_Role__c ar : tempARList) {
                        if (ar.Role_Type__c == 'Legal Owner') {
                            aCase.Party_of_Legal_Owner__c = ar.Party__c;
                        } else {
                            aCase.Party_of_Payer__c = ar.Party__c;
                        }
                    }
                }
            }
        }
    }

    /**
    @description On creation of a case this method will link an Account Role or Customer Product Role.
    @author  Nikita Phutane (Updated by Vegard Sørheller 08.11.2021)
    @date   14.06.2019
    @param cases list of cases from trigger
    **/
    public static void matchEmailToContactAndAccount(List<Case> cases) {
        List<String> emails = new List<String>();
        List<Case> casesWithEmail = new List<Case>();

        getCasesWithSuppliedEmail(cases, emails, casesWithEmail);

        if (emails.isEmpty()) {
            return;
        }

        Map<String, List<EmailMatchResult>> resultsByEmail = new Map<String, List<EmailMatchResult>>();
        addAccountRolesByEmails(emails, resultsByEmail);
        addCustomerProductRolesByEmails(emails, resultsByEmail);

        for (Case aCase : casesWithEmail) {
            EmailMatchResult[] matches = resultsByEmail.get(aCase.SuppliedEmail);
            if (matches == null || matches.isEmpty()) {
                continue;
            }
            matches.sort();
            List <EmailMatchResult> bestMatches = findBestMatches(matches, aCase);
            if (bestMatches != null && !bestMatches.isEmpty()) {
                EmailMatchResult result = intersect(bestMatches);
                aCase.Party__c = result.party;
                aCase.AccountId = result.account;
                aCase.AssetId = result.asset;
            }
        }
    }

    /**
    @description Extracting the emails and the cases with supplied emails and brand from the list of cases from trigger.
    @author  Vegard Sørheller
    @date   08.11.2021
    @param casesFromTrigger list of cases from trigger
    @param emails list of supplied emails from cases
    @param emailCases list of cases with supplied email and brand
    **/
    private static void getCasesWithSuppliedEmail(List<Case> casesFromTrigger, List<String> emails, List<Case> emailCases) {
        for (Case aCase : casesFromTrigger) {
            if (String.isNotBlank(aCase.SuppliedEmail) && aCase.Brand__c != null
                    && (!getBypassEmails().contains(aCase.SuppliedEmail))) {
                emails.add(aCase.SuppliedEmail);
                emailCases.add(aCase);
            }
        }
    }

    /**
    @description Getting emails that should not be related to a case.
    @author  Vegard Sørheller
    @date   08.11.2021
    @return Set of emails that should not be related to a case
    **/
    private static Set<String> getBypassEmails() {
        Set<String> bypassEmails = new Set<String>();
        Emails_to_bypass_assoc_logic__mdt[] emailBypassList = [SELECT DeveloperName, Email__c FROM Emails_to_bypass_assoc_logic__mdt];
        for (Emails_to_bypass_assoc_logic__mdt tempEmailList : emailBypassList) {
            bypassEmails.add(tempEmailList.Email__c);
        }
        return bypassEmails;
    }

    /**
    @description Finds all Account Roles with matching email
    @author  Vegard Sørheller
    @date   08.11.2021
    **/
    private static void addAccountRolesByEmails(List<String> emails, Map<String, List<EmailMatchResult>> resultsByEmail) {
        for (Account_Role__c accountRole : getAccountRoles(emails)) {
            if (!resultsByEmail.containsKey(accountRole.Email__c)) {
                resultsByEmail.put(accountRole.Email__c, new List<EmailMatchResult>());
            }
            resultsByEmail.get(accountRole.Email__c).add(new EmailMatchResult(accountRole));
        }
    }

    /**
    @description Finds all Customer Product Roles with matching email
    @author  Vegard Sørheller
    @date   08.11.2021
    **/
    private static void addCustomerProductRolesByEmails(List<String> emails, Map<String, List<EmailMatchResult>> resultsByEmail) {
        for (Customer_Product_Role__c customerProductRole : getCustomerProductRoles(emails)) {
            if (!resultsByEmail.containsKey(customerProductRole.Email__c)) {
                resultsByEmail.put(customerProductRole.Email__c, new List<EmailMatchResult>());
            }
            resultsByEmail.get(customerProductRole.Email__c).add(new EmailMatchResult(customerProductRole));
        }
    }

    /**
    @description Finds all Account Roles with matching email from database
    @author  Vegard Sørheller
    @date   08.11.2021
    @return Results from database
    **/
    private static List<Account_Role__c> getAccountRoles(List<String> emails) {
        List<Account_Role__c> accountRoles = [
                SELECT Id, Name, Email__c, Party__c, Party__r.Name, Account__c, Role_Type__c, Brand__c, Account__r.Status__c
                FROM Account_Role__c
                WHERE Email__c IN:emails
                ORDER BY Account__r.Status__c ASC, Role_Type__c ASC, Customer_Since__c DESC
        ];
        return accountRoles;
    }

    /**
    @description Finds all Customer Product Roles with matching email from database
    @author  Vegard Sørheller
    @date   08.11.2021
    @return Results from database
    **/
    private static List<Customer_Product_Role__c> getCustomerProductRoles(List<String> emails) {
        List<Customer_Product_Role__c> customerProductRoles = [
                SELECT Id, Name, Email__c, asset__c, Party__c, Party__r.Name, Role_Type__c, Brand__c, asset__r.Status
                FROM Customer_Product_Role__c
                WHERE Email__c IN:emails
                ORDER BY asset__r.Status ASC, Role_Type__c DESC
        ];
        return customerProductRoles;
    }

    /**
    @description Finds the best role matches for the particular case based on brand, status and role type
    @author  Vegard Sørheller
    @date   08.11.2021
    @return List of best role matches for the particular case
    **/
    private static List<EmailMatchResult> findBestMatches(EmailMatchResult[] matches, Case aCase) {
        List<EmailMatchResult> bestMatches = new List<EmailMatchResult>();
        EmailMatchResult bestMatch;
        for (EmailMatchResult emailMatchResult : matches) {
            if (emailMatchResult.brand == aCase.Brand__c) {
                if (bestMatch == null) bestMatch = emailMatchResult;
                if (bestMatch != null && bestMatch.compareTo(emailMatchResult) == 0) {
                    bestMatches.add(emailMatchResult);
                } else {
                    break;
                }
            }
        }
        return bestMatches;
    }

    public static EmailMatchResult intersect(List<EmailMatchResult> emailMatchResults) {
        EmailMatchResult result;
        if (emailMatchResults != null || !emailMatchResults.isEmpty()) {
            result = emailMatchResults.get(0);
            for (EmailMatchResult emailMatchResult : emailMatchResults) {
                if (emailMatchResult.party != null && !emailMatchResult.party.equals(emailMatchResults.get(0).party)) {
                    result.party = null;
                }
                if (emailMatchResult.account != null && !emailMatchResult.account.equals(emailMatchResults.get(0).account)) {
                    result.account = null;
                }
                if (emailMatchResult.asset != null && !emailMatchResult.asset.equals(emailMatchResults.get(0).asset)) {
                    result.asset = null;
                }
            }
        }
        return result;
    }

    /**
     * @description ENUM for the different role types
     * @author Vegard Sørheller
     * @date 08.11.2021
     */
    public enum RoleTypeEnum {
        LEGAL_OWNER, INVOICE_RECEIVER, CUSTOMER_PRODUCT_ROLE
    }

    /**
     * @description Wrapper class to represent a role type
     * @author Vegard Sørheller
     * @date 08.11.2021
     */
    public class EmailMatchResult implements Comparable {
        String account;
        String asset;
        String party;
        String status;
        String brand;
        RoleTypeEnum roleType;

        public EmailMatchResult(Account_Role__c role) {
            this.account = role.Account__c;
            this.party = role.Party__c;
            this.status = role.Account__r?.Status__c;
            this.brand = role.Brand__c;
            this.roleType = role.Role_Type__c == 'Legal Owner' ? RoleTypeEnum.LEGAL_OWNER : RoleTypeEnum.INVOICE_RECEIVER;
        }

        public EmailMatchResult(Customer_Product_Role__c role) {
            this.asset = role.asset__c;
            this.party = role.Party__c;
            this.status = role.asset__r?.Status;
            this.brand = role.Brand__c;
            this.roleType = RoleTypeEnum.CUSTOMER_PRODUCT_ROLE;
        }

        public Integer compareTo(Object other) {
            EmailMatchResult that = (EmailMatchResult) other;

            if (this.status != that.status) {
                if (this.status == 'Active') {
                    return 1;
                } else if (that.status == 'Active') {
                    return -1;
                }
            }
            return this.roleType.ordinal() - that.roleType.ordinal();
        }
    }

    /**
     * @description Method updates Case Subject and appends Case Sub Category to Subject
     * @author Andrzej Radziejewski
     * @date 25.02.2020 (updated 24.03.2020 by Darius Pilkis) (updated 23.04.2021 by Simas Ramoska)
     *
     * @param caseList List with Cases from Trigger
     */
    public static void updateSubjectOnCase(List<Case> caseList) {
        Map<String, String> pickListValuesMap = new Map<String, String>();
        Schema.DescribeFieldResult fr = Case.Sub_Category__c.getDescribe();
        List<Schema.PicklistEntry> ple = fr.getPicklistValues();
        for (Schema.PicklistEntry pickListVal : ple) {
            pickListValuesMap.put(pickListVal.getValue(), pickListVal.getLabel());
        }

        for (Case c : caseList) {
            if (c.Sub_Category__c != null) {
                if (c.Subject == null) {
                    c.Subject = pickListValuesMap.get(c.Sub_Category__c);
                }
            }
        }
    }

    /**
     * @description Method updates Date Time Assigned field when case status changes from Registered to In Progress
     * @author Akshata Asukar
     * @date 07.07.2020
     * @param cases List of Cases with new field values from Trigger
     * @param oldMap  Map of Cases with old field values.
     */
    public static void updateDateTimeAssigned(List<Case> cases, Map<Id, Case> oldMap) {
        for (Case caseObj : cases) {
            if (oldMap.get(caseObj.Id).Status == 'Registered' && caseObj.Status == 'In Progress') {
                caseObj.Date_Time_Assigned__c = System.now();
            }
        }
    }

    /**
     * @description Method updates Brand on case when the account on Case is updated.
     * @author Akshata Asukar
     * @date 31.08.2020
     * @modified by Edgaras (26.04.2021)
     * @param cases List of Cases with new field values from Trigger
     * @param oldCaseMap  Map of Cases with old field values.
     */
    public static void updateBrandOnCase(List<Case> cases, Map<Id, Case> oldCaseMap) {
        Map<Id, Account> accountMap = new Map<Id, Account>();
        Set<Id> caseIds = new Set<Id>();
        for (Case caseObj : cases) {
            Case oldCase = oldCaseMap != null ? oldCaseMap.get(caseObj.Id) : null;
            if (caseObj.AccountId != null && (oldCase != null && caseObj.AccountId != oldCase.AccountId)) {
                accountMap.put(caseObj.AccountId, null);
                caseIds.add(caseObj.Id);
            } else if (caseObj.AccountId != null && oldCase == null) {
                accountMap.put(caseObj.AccountId, null);
                caseIds.add(caseObj.Id);
            }
            if (caseObj.AccountId == null && (oldCase != null && caseObj.AccountId != oldCase.AccountId)) {
                caseObj.Brand__c = '';
            }
        }

        if (!accountMap.isEmpty()) {
            List<Account> accounts = [SELECT Id,Brand__c FROM Account WHERE Id IN:accountMap.keySet()];
            for (Account account : accounts) {
                accountMap.put(account.Id, account);
            }
        }

        for (Case caseObj : cases) {
            if (!caseIds.isEmpty() && !accountMap.isEmpty() && caseIds.contains(caseObj.Id) && accountMap.containsKey(caseObj.AccountId) && accountMap.get(caseObj.AccountId) != null) {
                caseObj.Brand__c = accountMap.get(caseObj.AccountId).Brand__c;
            }
        }


    }

    /**
     * @description Method that counts the number of hours a case was in waiting status when a case is resolved.
     * @author Akshata Asukar
     * @date 08.10.2020
     * @param newMap List of Cases with new field values from Trigger.new and Old case map trigger.Old
     * @param oldMap NOT DONE.
     */
    public static void calculateWaitingTime(Map<Id, Case> newMap, Map<Id, Case> oldMap) {
        Set<Id> resolvedCaseIds = new Set<Id>();
        for (Id caseId : newMap.keySet()) {
            if (newMap.get(caseId).Status == 'Resolved' && oldMap.get(caseId).Status != 'Resolved') {
                resolvedCaseIds.add(caseId);
            }
        }
        if (resolvedCaseIds.size() == 0) {
            return;
        }
        List<Case> casesWithRelatedHistories = [SELECT Id, (SELECT Id,CaseId, CreatedDate, OldValue, NewValue FROM Histories WHERE Field = 'Status' ORDER BY CreatedDate ASC) FROM Case WHERE Id IN :resolvedCaseIds];
        for (Case caseObj : casesWithRelatedHistories) {
            List<CaseHistoryWrapper> historyWrappers = new List<CaseHistoryWrapper>();
            if (caseObj.Histories != null) {
                for (CaseHistory history : caseObj.Histories) {
                    historyWrappers.add(new CaseHistoryWrapper(history.CreatedDate, String.valueOf(history.NewValue), String.valueOf(history.OldValue)));
                }
                if (oldMap.get(caseObj.Id).Status == 'Waiting' && newMap.get(caseObj.Id).Status == 'Resolved') {
                    historyWrappers.add(new CaseHistoryWrapper(Datetime.now(), 'Resolved', 'Waiting'));
                }

                Decimal hours = getDurationFromHistory(historyWrappers);
                newMap.get(caseObj.Id).Waiting_time__c = hours;
            }
        }
    }

    /**
    * @description Method to calculate the hours spent in waiting status, it takes into consideration that a case can be in waiting status more than one time.
    * @author Akshata Asukar
    * @date 09.10.2020
    * @param caseHistories the related case history records for a case where Field is Status.
    * @return Decimal hours calculated for a given list of case histories
    */
    public static Decimal getDurationFromHistory(List<CaseHistoryWrapper> caseHistories) {
        Decimal hours;
        Boolean inWaiting = false;
        Datetime waitStart = null;
        Long sum = 0;

        for (CaseHistoryWrapper his : caseHistories) {
            if (his.NewValue == 'Waiting') {
                inWaiting = true;
                waitStart = his.CreatedDateTime;
            }
            if (inWaiting && his.NewValue != 'Waiting') {
                sum += his.CreatedDateTime.getTime() - waitStart.getTime();
                inWaiting = false;
            }
        }

        hours = (Double) sum / 1000 / 60 / 60;
        return (Decimal) hours.round();
    }

    /**
   * @description Wrapper to map CaseHistory records, which will be used for calculation of time spent in waiting status.
   *              As Histories records cannot be created in test class scenario, it was decided to use wrapper instead of
   *              actual CaseHistory records to perform the calculations.
   */
    public class CaseHistoryWrapper {
        public Datetime CreatedDateTime;
        public String NewValue;
        public String OldValue;

        public CaseHistoryWrapper(Datetime CreatedDateTime, String newValue, String oldValue) {
            this.CreatedDateTime = CreatedDateTime;
            this.NewValue = newValue;
            this.OldValue = oldValue;
        }
    }

    /**
    * @description Method that counts all Customer Contacts (Received Emails and Customer Interaction) and updates Customer_Contacts__c
    * on case with value when case status = resolved.
    * @author Jon Ørevik
    * @date 08.10.2020
    * @param newMap List of Cases with new field values from Trigger.new
     * @param oldMap NOT DONE.
    */
    public static void countCustomerContacts(Map<Id, Case> newMap, Map<Id, Case> oldMap) {
        Set<Id> resolvedCasesIds = new Set<Id>();
        for (Case caseObj : newMap.values()) {
            if ((newMap.get(caseObj.Id).Status == 'Closed' || newMap.get(caseObj.Id).Status == 'Resolved') && newMap.get(caseObj.Id).Status != oldMap.get(caseObj.Id).Status) {
                resolvedCasesIds.add(caseObj.Id);
            }
        }

        if (!resolvedCasesIds.isEmpty()) {
            List<Case> casesWithCustomerContacts = [
                    SELECT Id, (SELECT Id FROM EmailMessages WHERE Incoming = TRUE AND Check_From_Address__c = 0), (SELECT Id FROM Customer_Interactions__r)
                    FROM Case
                    WHERE Id IN :resolvedCasesIds
            ];
            for (Case aCase : casesWithCustomerContacts) {
                //Fetch emails from customers and customer interactions, sum them up and add the sum to Customer_Contacts__c
                Integer emails = aCase.EmailMessages == null ? 0 : aCase.EmailMessages.size();
                Integer customerInteractions = aCase.Customer_Interactions__r == null ? 0 : aCase.Customer_Interactions__r.size();
                newMap.get(aCase.Id).Customer_Contacts__c = emails + customerInteractions;
            }
        }
    }

    /**
    * @description Method that sets Customer_Contacts__c field to 1 when Case is created as Resolved
    * @author Simas Ramoska
    * @date 22.06.2021
    * @param caseList List of Cases with field values from Trigger.new
    */
    public static void countCustomerContactsOnInsert(List<Case> caseList) {
        for (Case insertedCase : caseList) {
            if (insertedCase.Status == 'Resolved' && insertedCase.Customer_Contacts__c == null) {
                insertedCase.Customer_Contacts__c = 1;
            }
        }
    }

    /**
     * @description Handler method to check if the case is set to "In Progress" and if that is done by a User with the profile "In Progress 2nd Line" set the status to "Customer Care Agent 2nd Line" instead.
     * @author Henrik Olsen.
     * @date 27.05.2021.
     * @param cases List of Cases from Trigger.new
     * @param oldCases Map of Ids and Cases from Trigger.oldMap.
     */
    public static void handleDifferentInProgressStatuses(List<Case> cases, Map<Id, Case> oldCases) {
        for (Case aCase : cases) {
            if (UserInfo.getProfileId() == PROFILE_ID_CUSTOMER_CARE_AGENT_2ND_LINE &&
                    aCase.Status == CASE_STATUS_IN_PROGRESS &&
                    (Trigger.isInsert || (Trigger.isUpdate && aCase.Status != oldCases.get(aCase.Id).Status &&
                            !(aCase.Personally_Follow_up__c == false && oldCases.get(aCase.Id).Personally_Follow_up__c == true) && !(aCase.Transferred_To_First_Line__c == true && oldCases.get(aCase.Id).Transferred_To_First_Line__c == false)))) {
                aCase.Status = CASE_STATUS_IN_PROGRESS_2ND_LINE;
            }
        }
    }

    /**
     * @description Method that censors Description when inserted or changed.
     * @author Henrik Olsen.
     * @date 10.02.2022
     * @param cases List of new Cases.
     * @param oldMap Map of Old Cases
     * @param isInsert Trigger.IsInsert.
     */
    public static void handleDescriptionSSNCensoring(List<Case> cases, Map<Id, Case> oldMap, Boolean isInsert) {
        for (Case aCase : cases) {
            Case oldCase = !isInsert ? oldMap.get(aCase.Id) : aCase;
            if ((isInsert || aCase.Description != oldCase.Description)) {
                if (String.isNotBlank(aCase.Description)) {
                    ssnRegexHandler.findMatches(aCase.Description);
                    if (ssnRegexHandler.hasMatches()) {
                        aCase.Description = ssnRegexHandler.censor(aCase.Description);
                    }
                }
            }
        }
    }
}