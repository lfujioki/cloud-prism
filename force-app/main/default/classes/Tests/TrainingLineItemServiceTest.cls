@IsTest
private class TrainingLineItemServiceTest {

    @TestSetup
    static void setup() {
        Restaurant__c restaurant = new Restaurant__c();
        restaurant.Name = 'Tam O\'Shanter';
        restaurant.CommissionRate__c = 15;
        restaurant.AverageMealCost__c = 55;
        insert restaurant;

        Training__c training = new Training__c();
        training.Name = 'Test Trigger Training';
        training.Restaurant__c = restaurant.Id;
        training.StartDate__c = System.today().addMonths(1);
        training.EndDate__c = System.today().addMonths(1);
        training.TotalPrice__c = 120.00;
        training.TotalTax__c = 22.80;
        insert training;

        TrainingProduct__c product1 = new TrainingProduct__c();
        product1.Name = 'Test Product Course';
        product1.ProductCode__c = 'TOC00001';
        product1.ProductPrice__c = 100;
        product1.ProductDescription__c = 'Course fee';

        TrainingProduct__c product2 = new TrainingProduct__c();
        product2.Name = 'Test Product Materials';
        product2.ProductCode__c = 'TPM00001';
        product2.ProductPrice__c = 10;
        product2.ProductDescription__c = 'Materials fee';

        List<TrainingProduct__c> products = new List<TrainingProduct__c> {product1, product2};
        insert products;
    }

    @IsTest
    static void beforeInsertTrigger_UnitTest() {
        List<TrainingProduct__c> products = [SELECT Id FROM TrainingProduct__c];

        TrainingLineItem__c item1 = new TrainingLineItem__c();
        item1.Name = '1';
        item1.TrainingProduct__c = products.get(0).Id;

        TrainingLineItem__c item2 = new TrainingLineItem__c();
        item2.Name = '2';
        item2.TrainingProduct__c = products.get(1).Id;

        List<TrainingLineItem__c> items = new List<TrainingLineItem__c> {item1, item2};

        Test.startTest();
        insert items;
        Test.stopTest();

        List<TrainingLineItem__c> insertedLineItems = [
            SELECT Name, ProductCode__c, LineDescription__c, Price__c, Tax__c
            FROM TrainingLineItem__c
        ];

        Assert.areEqual(2, insertedLineItems.size());

        for(TrainingLineItem__c lineItem : insertedLineItems) {
            Assert.isNotNull(lineItem.Price__c);
            Assert.isNotNull(lineItem.Tax__c);
        }
    }

    @IsTest
    static void afterInsertTrigger_UnitTest() {
        Decimal expectedTotalPrice = 0.0;
        Decimal expectedTotalTax = 0.0;

        List<TrainingProduct__c> products = [SELECT Id FROM TrainingProduct__c];
        Training__c beforeInsertTraining = [SELECT Id, TotalPrice__c, TotalTax__c FROM Training__c];

        TrainingLineItem__c item1 = new TrainingLineItem__c();
        item1.Name = '1';
        item1.Training__c = beforeInsertTraining.Id;
        item1.TrainingProduct__c = products.get(0).Id;

        TrainingLineItem__c item2 = new TrainingLineItem__c();
        item2.Name = '2';
        item2.Training__c = beforeInsertTraining.Id;
        item2.TrainingProduct__c = products.get(1).Id;

        List<TrainingLineItem__c> items = new List<TrainingLineItem__c> {item1, item2};

        Test.startTest();
        insert items;
        Test.stopTest();

        List<TrainingLineItem__c> insertedLineItems = [SELECT Id, Price__c, Tax__c FROM TrainingLineItem__c];

        Assert.areEqual(2, insertedLineItems.size());

        for(TrainingLineItem__c lineItem : insertedLineItems) {
            expectedTotalPrice += lineItem.Price__c;
            expectedTotalTax += lineItem.Tax__c;
        }

        Training__c training = [SELECT Id, TotalPrice__c, TotalTax__c FROM Training__c LIMIT 1];

        Assert.areEqual(expectedTotalPrice, training.TotalPrice__c);
        Assert.areEqual(expectedTotalTax, training.TotalTax__c);
    }

    @IsTest
    static void beforeUpdateTrigger_UnitTest() {
        TrainingProduct__c product3 = new TrainingProduct__c();
        product3.Name = 'Test Product Registration';
        product3.ProductCode__c = 'TPR00001';
        product3.ProductPrice__c = 30;
        product3.ProductDescription__c = 'Registration fee';
        insert product3;

        List<TrainingProduct__c> products = [
            SELECT Id, ProductCode__c, ProductPrice__c, ProductTax__c, ProductDescription__c 
            FROM TrainingProduct__c
        ];

        TrainingLineItem__c item1 = new TrainingLineItem__c();
        item1.Name = '1';
        item1.TrainingProduct__c = products.get(0).Id;

        TrainingLineItem__c item2 = new TrainingLineItem__c();
        item2.Name = '2';
        item2.TrainingProduct__c = products.get(1).Id;

        List<TrainingLineItem__c> items = new List<TrainingLineItem__c> {item1, item2};
        insert items;

        item1.TrainingProduct__c = products.get(2).Id;

        Test.startTest();
        update item1;
        Test.stopTest();

        TrainingLineItem__c updatedLineItem = [
            SELECT Name, ProductCode__c, LineDescription__c, Price__c, Tax__c
            FROM TrainingLineItem__c
            WHERE Price__c = 30
        ];

        Assert.areEqual(product3.ProductPrice__c, updatedLineItem.Price__c);
        Assert.areEqual(product3.ProductCode__c, updatedLineItem.ProductCode__c);
        Assert.areEqual(product3.ProductDescription__c, updatedLineItem.LineDescription__c);
        Assert.areNotEqual(products.get(0).ProductTax__c, updatedLineItem.Tax__c);
    }

    @IsTest
    static void afterUpdateTrigger_UnitTest() {
        Decimal expectedTotalPrice = 0.0;
        Decimal expectedTotalTax = 0.0;

        List<TrainingProduct__c> products = [SELECT Id FROM TrainingProduct__c];
        Training__c beforeInsertTraining = [SELECT Id, TotalPrice__c, TotalTax__c FROM Training__c];

        TrainingLineItem__c item1 = new TrainingLineItem__c();
        item1.Name = '1';
        item1.Training__c = beforeInsertTraining.Id;
        item1.TrainingProduct__c = products.get(0).Id;

        TrainingLineItem__c item2 = new TrainingLineItem__c();
        item2.Name = '2';
        item2.Training__c = beforeInsertTraining.Id;
        item2.TrainingProduct__c = products.get(1).Id;

        List<TrainingLineItem__c> items = new List<TrainingLineItem__c> {item1, item2};
        insert items;

        item1.Price__c = 200.0;
        item1.Price__c = 20.0;

        Test.startTest();
        update item1;
        Test.stopTest();

        List<TrainingLineItem__c> updatedLineItems = [SELECT Id, Price__c, Tax__c FROM TrainingLineItem__c];

        Assert.areEqual(2, updatedLineItems.size());

        for(TrainingLineItem__c lineItem : updatedLineItems) {
            expectedTotalPrice += lineItem.Price__c;
            expectedTotalTax += lineItem.Tax__c;
        }

        Training__c training = [SELECT Id, TotalPrice__c, TotalTax__c FROM Training__c LIMIT 1];

        Assert.areEqual(expectedTotalPrice, training.TotalPrice__c);
        Assert.areEqual(expectedTotalTax, training.TotalTax__c);
    }

    @IsTest
    static void afterDeleteTrigger_UnitTest() {
        Decimal expectedTotalPrice = 0.0;
        Decimal expectedTotalTax = 0.0;

        TrainingProduct__c product3 = new TrainingProduct__c();
        product3.Name = 'Test Product Registration';
        product3.ProductCode__c = 'TPR00001';
        product3.ProductPrice__c = 30;
        product3.ProductDescription__c = 'Registration fee';
        insert product3;

        List<TrainingProduct__c> products = [SELECT Id FROM TrainingProduct__c];
        Training__c beforeInsertTraining = [SELECT Id, TotalPrice__c, TotalTax__c FROM Training__c];

        TrainingLineItem__c item1 = new TrainingLineItem__c();
        item1.Name = '1';
        item1.Training__c = beforeInsertTraining.Id;
        item1.TrainingProduct__c = products.get(0).Id;

        TrainingLineItem__c item2 = new TrainingLineItem__c();
        item2.Name = '2';
        item2.Training__c = beforeInsertTraining.Id;
        item2.TrainingProduct__c = products.get(1).Id;

        TrainingLineItem__c item3 = new TrainingLineItem__c();
        item3.Name = '3';
        item3.Training__c = beforeInsertTraining.Id;
        item3.TrainingProduct__c = products.get(2).Id;

        List<TrainingLineItem__c> items = new List<TrainingLineItem__c> {item1, item2, item3};
        insert items;

        Test.startTest();
        delete item3;
        Test.stopTest();

        List<TrainingLineItem__c> remainingLineItems = [SELECT Id, Price__c, Tax__c FROM TrainingLineItem__c];

        Assert.areEqual(2, remainingLineItems.size());

        for(TrainingLineItem__c lineItem : remainingLineItems) {
            expectedTotalPrice += lineItem.Price__c;
            expectedTotalTax += lineItem.Tax__c;
        }

        Training__c training = [SELECT Id, TotalPrice__c, TotalTax__c FROM Training__c LIMIT 1];

        Assert.areEqual(expectedTotalPrice, training.TotalPrice__c);
        Assert.areEqual(expectedTotalTax, training.TotalTax__c);
    }

}