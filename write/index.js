'use strict'

const AWS = require('aws-sdk')
const uuid = require('uuid')
const documentClient = new AWS.DynamoDB.DocumentClient()

exports.handler = (event, context, callback) => {
  const params = {
    Item: {
            "id": uuid.v1(),
            "name": event.name
          },
    TableName: process.env.TABLE_NAME
  }

  documentClient.put(params, (error, data) => callback(error, data))
}
