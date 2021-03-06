#套件----
library(caret)
library(randomForest)
library(ROCR)
library(cluster)
library(ggplot2)
library(neuralnet)
library(Ckmeans.1d.dp)
library(DiagrammeR)
library(InformationValue)
library(tree)
library(rpart.plot) 
library(DMwR)

#設定Data------
online =read.csv("online_shoppers_intention.csv",header = T)
online$Revenue = as.factor(online$Revenue)

ggplot(newData,aes(x = Revenue,fill=Revenue)) +
  geom_bar( stat="count") +
  geom_text(aes(label=paste0(round(stat(prop),3)*100,'%'), group=1),
            stat='count',position = position_dodge(width = 2.9),   
            vjust = 1.5,size = 15)+
  scale_fill_manual(values = c('coral1','Cornflower blue'))+
  guides(fill = "none")


set.seed(123)
table(online$Revenue)
newData <- SMOTE(Revenue ~ ., online, perc.over = 300,perc.under=133)
table(newData$Revenue)

newData$Revenue = ifelse(newData$Revenue == "TRUE" , 1 , 0  )
newData$Revenue = as.factor(newData$Revenue)
class(newData$Revenue)

#平衡資料----
#把Y1==0 的資料壓縮
set.seed(123)
datadown <- online[online$Revenue== "0",];dim(datadown)
k.max <- 30
asw <- rep(0,30)
for(i in 2:k.max){
  asw[i] = clara(datadown,i)$silinfo$avg.width
}
k.best <- which.max(asw)
print(k.best)
plot(1:30, asw[1:30],
     type="l", pch = 19, frame = FALSE, 
     xlab="Number of clusters K",
     ylab="Total within-clusters sum of squares")


#Y=0----
#In "y=0" part, the optimal number of clusters is _
set.seed(12345)
clustering <- clara(datadown,k.best)
datadown_cluster <- data.frame(datadown, clustering$cluster)
head(datadown_cluster)

cluster1 <- datadown_cluster[datadown_cluster$clustering.cluster==1,][,1:18]
cluster2 <- datadown_cluster[datadown_cluster$clustering.cluster==2,][,1:18]
cluster3 <- datadown_cluster[datadown_cluster$clustering.cluster==3,][,1:18]

set.seed(123)
n1 = cluster1[sample(nrow(cluster1), 0.9*nrow(cluster1),replace = F), ]
n2 = cluster2[sample(nrow(cluster2), 0.9*nrow(cluster2),replace = F), ]
n3 = cluster3[sample(nrow(cluster3), 0.9*nrow(cluster3),replace = F), ]


only.no <- rbind(n1,n2,n3)
table(only.no$Revenue)



#Y=1----
#Clustering & Resamping the minority part in onlineing Data
#About "y == 1" part
set.seed(123)
dataup <- online[online$Revenue == "1",];dim(dataup)
k.max <- 30
asw <- rep(0,30)
for(i in 2:k.max){
  asw[i] = clara(dataup,i)$silinfo$avg.width
}
k.best <- which.max(asw)
print(k.best)
plot(2:30, asw[2:30],
     type="l", pch = 19, frame = FALSE, 
     xlab="Number of clusters K",
     ylab="Total within-clusters sum of squares")

set.seed(12345)
clustering <- clara(dataup,k.best)
dataup_cluster <- data.frame(dataup, clustering$cluster)

cluster1 <- dataup_cluster[dataup_cluster$clustering.cluster==1,][,1:18]
cluster2 <- dataup_cluster[dataup_cluster$clustering.cluster==2,][,1:18]


set.seed(123)
n1 = cluster1[sample(nrow(cluster1), 5*nrow(cluster1),replace = T), ]
n2 = cluster2[sample(nrow(cluster2), 5*nrow(cluster2),replace = T), ]


online <- rbind(only.no,n1,n2)
table(online$Revenue)

#----logit regression--------------------------
#set null vactor
mis <- c()
pre <- c()
recall <- c()
spe <- c()
acu <- c()
#### logit regression
# model_logit  <- glm(formula = Revenue ~ ., 
#                     data = newData,family = binomial(link = "logit"))
set.seed(123)
datarandom<- newData[sample(nrow(newData)),]
folds <- cut(seq(1,nrow(datarandom)),breaks=10,labels=FALSE)

for(i in 1:10){
  testIndexes <- which(folds==i,arr.ind=TRUE)
  test_data1 <- datarandom[testIndexes, ]
  train_data1 <- datarandom[-testIndexes, ]
  
  model_logit  <- glm(formula = Revenue ~ ProductRelated_Duration +
                        ExitRates  + Month + SpecialDay + 
                        OperatingSystems + VisitorType,
                      data = train_data1 ,family = binomial(link = "logit"))
  
  prob_logit <- predict(model_logit , test_data1 , type="response" )
  optCutOff <- optimalCutoff(actuals = test_data1$Revenue , previfdictedScores = prob_logit)[1]
  pre_logit = cut(prob_logit, breaks=c(-Inf, optCutOff, Inf), labels=c(0, 1))
  matrix = table(pre_logit ,test_data1$Revenue)
  acu[i] <-     (matrix[1,1]+matrix[2,2])/sum(matrix)
  pre[i] <-     matrix[2,2]/(sum(matrix[2,]))
  recall[i] <-  matrix[2,2]/(sum(matrix[,2]))
}
output_logit <- data.frame(
  accuracy = acu,
  precision = pre,
  sensitivity = recall
)
avg_output_logit<- data.frame(
  accuracy = mean(acu),
  precision = mean(pre),
  sensitivity = mean(recall),
  f1 = mean(2 * pre * recall / (pre + recall))
)
round(avg_output_logit,4)
vif(model_logit)
#plotROC(test_data1$Revenue, prob_logit)

# 我們建立一個存放模型偏差殘差的資料表
index <- 1:dim(train_data1)[1]
# deviance residuals
dev_resid <- residuals(model_logit)
revenue <- train_data1$Revenue
dff <- data.frame(index,dev_resid,revenue)

ggplot(data = dff, mapping = aes(x = index,y = dev_resid,color = revenue)) +
  geom_point() +
  geom_hline(yintercept = 3,linetype = "dashed", color = "blue") +
  geom_hline(yintercept = -3,linetype = "dashed", color = "blue") +
  labs(title = "Plot of Deviance Residuals") +
  theme(plot.title = element_text(hjust = 0.5))




#--------------
#RandomForest
library(randomForest)
set.seed(123)
datarandom<- newData[sample(nrow(newData)),]
folds <- cut(seq(1,nrow(datarandom)),breaks=10,labels=FALSE)
for(i in 1:10){
  testIndexes <- which(folds==i,arr.ind=TRUE)
  test_data2 <- datarandom[testIndexes, ]
  train_data2 <- datarandom[-testIndexes, ]
  
  model_rd <- randomForest(as.factor(Revenue) ~ ProductRelated_Duration +
                             ExitRates  + Month + SpecialDay + 
                             OperatingSystems + VisitorType,
                           data = train_data2, n_tree = 500, mtry=6,
                           nodesize=25, importance=TRUE )
  prob_rd <- predict(model_rd , test_data2 , type="prob" )
  pre_rd <- predict(model_rd , test_data2 , type="class" )
  matrix = table(pre_rd ,test_data2$Revenue)
  acu[i] <-     (matrix[1,1]+matrix[2,2])/sum(matrix)
  pre[i] <-     matrix[2,2]/(sum(matrix[2,]))
  recall[i] <-  matrix[2,2]/(sum(matrix[,2]))
}
output_rd <- data.frame(
  accuracy = acu,
  precision = pre,
  sensitivity = recall,
)
avg_output_rd <- data.frame(
  accuracy = mean(acu),
  precision = mean(pre),
  sensitivity = mean(recall),
  f1 = mean(2 * pre * recall / (pre + recall))
)
round(avg_output_rd,4)
varImpPlot(model_rd)

library(car)
vif(model_logit)

##------Support Vector Machine(SVM)-------
library(e1071)
online$Revenue = as.factor(online$Revenue)
model_svm <- svm(formula =  Revenue ~ Administrative + Informational + ProductRelated +
                   BounceRates + ExitRates + PageValues + Month + 
                   OperatingSystems + Browser + Region + VisitorType + Weekend,
                 data = online)
#-------tune parameters in SVM
library("mlbench")
tune.model = tune(svm,
                  Revenue ~ Administrative + Informational + ProductRelated +
                    BounceRates + ExitRates + PageValues + Month + 
                    OperatingSystems + Browser + Region + VisitorType + Weekend,
                  data=online,
                  kernel="radial", # RBF kernel function
                  range=list(cost=10^(-1:2), gamma=c(0.5,1,2)))


set.seed(123)
datarandom<- online[sample(nrow(online)),]
folds <- cut(seq(1,nrow(datarandom)),breaks=10,labels=FALSE)
for(i in 1:10){
  testIndexes <- which(folds==i,arr.ind=TRUE)
  test_data4 <- datarandom[testIndexes, ]
  train_data4 <- datarandom[-testIndexes, ]
  
  model_svm <- svm(formula =  Revenue ~ Administrative + Informational + ProductRelated +
                     BounceRates + ExitRates + PageValues + Month + 
                     OperatingSystems + Browser + Region + VisitorType + Weekend, cost = 1, gamma = 0.5,
                   data = train_data4)
  
  prob_svm <- predict(object = model_svm , newdata = test_data4, type = "response")
  optCutOff <- optimalCutoff(actuals = test_data4$Revenue , predictedScores = prob_svm)[1]
  prob_svm = cut(prob_svm, breaks=c(-Inf, optCutOff, Inf), labels=c(0, 1))
  matrix = table(prob_svm ,test_data4$Revenue)
  acu[i] <-     (matrix[1,1]+matrix[2,2])/sum(matrix)
  pre[i] <-     matrix[2,2]/(sum(matrix[2,]))
  recall[i] <-  matrix[2,2]/(sum(matrix[,2]))
}
output_svm <- data.frame(
  accuracy = acu,
  precision = pre,
  sensitivity = recall,
  specificity = spe
)
avg_output_svm <- data.frame(
  accuracy = mean(acu),
  precision = mean(pre),
  sensitivity = mean(recall),
  f1 = mean(2 * pre * recall / (pre + recall))
)
round(avg_output_svm,4)


#--------------
#決策樹CART
library(rpart)
set.seed(123)
datarandom<- newData[sample(nrow(newData)),]
folds <- cut(seq(1,nrow(datarandom)),breaks=10,labels=FALSE)

for(i in 1:10){
  testIndexes <- which(folds==i,arr.ind=TRUE)
  test_data3 <- datarandom[testIndexes, ]
  train_data3 <- datarandom[-testIndexes, ]
  model_tree <- rpart(formula = as.factor(Revenue) ~ ProductRelated_Duration +
                        ExitRates  + Month + SpecialDay + 
                        OperatingSystems + VisitorType,
                      data = train_data3, method = "class",cp = 1e-4)
  
  prob_tree <- predict(object = model_tree , newdata = test_data3, type = "prob")
  pre_tree <- predict(object = model_tree , newdata = test_data3, type = "class")
  
  matrix = table(pre_tree ,test_data3$Revenue)
  acu[i] <-     (matrix[1,1]+matrix[2,2])/sum(matrix)
  pre[i] <-     matrix[2,2]/(sum(matrix[2,]))
  recall[i] <-  matrix[2,2]/(sum(matrix[,2]))
}
output_tree <- data.frame(
  accuracy = acu,
  precision = pre,
  sensitivity = recall
)
avg_output_tree <- data.frame(
  accuracy = mean(acu),
  precision = mean(pre),
  sensitivity = mean(recall),
  f1 = mean(2 * pre * recall / (pre + recall))
)
round(avg_output_tree,4)


rpart.plot(model_tree)

#--------------
#Neural Netwoarks(NN)
library(nnet)
set.seed(123)
datarandom<- newData[sample(nrow(newData)),]
folds <- cut(seq(1,nrow(datarandom)),breaks=10,labels=FALSE)
for(i in 1:10){
  testIndexes <- which(folds==i,arr.ind=TRUE)
  test_data5 <- datarandom[testIndexes, ]
  train_data5 <- datarandom[-testIndexes, ]
  
model_nn1 <- nnet(as.factor(Revenue) ~ ProductRelated_Duration +
                    ExitRates  + Month + SpecialDay + 
                    OperatingSystems + VisitorType,
            data = test_data5 ,size = 40 , maxit = 500) 
prob_nn1 <- predict(model_nn1 , test_data5 , type="raw" )
pre_nn1 <- predict(model_nn1 , test_data5 , type="class" )
matrix = table(pre_nn1 ,test_data5$Revenue)
acu[i] <-     (matrix[1,1]+matrix[2,2])/sum(matrix)
pre[i] <-     matrix[2,2]/(sum(matrix[2,]))
recall[i] <-  matrix[2,2]/(sum(matrix[,2]))
spe[i] <-     matrix[2,2]/(sum(matrix[,2]))
}
output_nn1 <- data.frame(
  accuracy = acu,
  precision = pre,
  sensitivity = recall
)
avg_output_nn1 <- data.frame(
  accuracy = mean(acu),
  precision = mean(pre),
  sensitivity = mean(recall),
  f1 = mean(2 * pre * recall / (pre + recall))
)
round(avg_output_nn1,4)

plotROC(test_data1$Revenue, prob_logit)

library(ROCR)
pr_logit <- prediction(prob_logit, test_data1$Revenue)
prf_logit <- performance(prediction.obj = prob_logit , measure = "tpr", x.measure = 'fpr')
dd_logit <- data.frame(FP = prf_logit@x.values[[1]], TP = prf_logit@y.values[[1]])

pr_rd <- prediction(prob_rd[,2] , test_data2$Revenue)
prf_rd <- performance(prediction.obj = pr_rd , measure = "tpr", x.measure = 'fpr')
dd_rd <- data.frame(FP = prf_rd@x.values[[1]], TP = prf_rd@y.values[[1]])

pr_tree <- prediction(prob_tree[,2] , test_data3$Revenue)
prf_tree <- performance(prediction.obj = pr_tree , measure = "tpr", x.measure = 'fpr')
dd_tree <- data.frame(FP = prf_tree@x.values[[1]], TP = prf_tree@y.values[[1]])

# pr_svm <- prediction(predictions = as.numeric(prob_svm) , labels = test_data4$Revenue)
# prf_svm <- performance(prediction.obj = pr_svm , measure = "tpr", x.measure = 'fpr')
# dd_svm <- data.frame(FP = prf_svm@x.values[[1]], TP = prf_svm@y.values[[1]])

pr1 <- prediction(prob_nn1, test_data5$Revenue)
prf1 <- performance(prediction.obj = pr1,measure = "tpr",x.measure = "fpr")
dd1 <- data.frame(FP = prf1@x.values[[1]], TP = prf1@y.values[[1]])



library(ggplot2)
g <- 
  ggplot() +
  geom_line(data = dd_logit , mapping = aes(x = FP, y = TP, color = 'Logistic Regression')) +
  geom_line(data = dd_tree , mapping = aes(x = FP, y = TP, color = 'CART')) +
  geom_line(data = dd_rd , mapping = aes(x = FP, y = TP, color = 'Random Forest')) +
  geom_line(data = dd_svm,mapping = aes(x = FP, y = TP, color = 'Support Vector Machine')) +
  geom_segment(mapping = aes(x = 0, xend = 1, y = 0, yend = 1)) +
  ggtitle(label = "ROC Curve") +
  labs(x = "False Positive Rate", y = "True Positive Rate")
g +
  scale_color_manual(name = "classifier",values = c('Logistic Regression'='#E69F00', 
                                                    'CART'='#009E73',
                                                    'Random Forest'='#D55E00',
                                                    'Support Vector Machine'='#0072B2'))


library("pROC") 
roc1 <- roc(test_data1$Revenue, prob_logit   , print.auc=TRUE,print.auc.x=0.3,print.auc.y=0.3)
roc2 <- roc(test_data2$Revenue, prob_rd[,2]  ,print.auc=TRUE,print.auc.x=0.3,print.auc.y=0.3)  
roc3 <- roc(test_data3$Revenue, prob_tree[,2],print.auc=TRUE,print.auc.x=0.5,print.auc.y=0.5)  
roc4 <- roc(test_data5$Revenue, prob_nn1     ,print.auc=TRUE,print.auc.x=0.6,print.auc.y=0.6) 
color =c("navy","firebrick","green4","navajowhite4")
plot(roc1, col="navy",print.auc=TRUE,print.auc.x=0.8,print.auc.y=0.6)  
plot.roc(roc2, add=TRUE, col="firebrick" ,print.auc=TRUE,print.auc.x=0.8,print.auc.y=0.5)
plot.roc(roc3, add=TRUE, col="green4",print.auc=TRUE,print.auc.x=0.8,print.auc.y=0.4)
plot.roc(roc4, add=TRUE, col="navajowhite4",print.auc=TRUE,print.auc.x=0.8,print.auc.y=0.3)
legend("bottomright",c("logistic regression","random forest","decision tree","neural networks"), cex = 1 , fill = color)



options(scipen = -1)
model_rd$importance %>% 
  as.matrix() %>% 
  as.data.frame() %>% 
  add_rownames() %>% 
  `colnames<-`(c("varname","imp")) %>%
  arrange(desc(imp)) %>% 
  top_n(25,wt = imp) %>% 
  ggplot(mapping = aes(x = reorder(varname, imp), y = imp)) +
  geom_col() +
  coord_flip() +
  ggtitle(label = "Top 25 important variables") +
  theme(
    axis.title = element_blank()
  )


