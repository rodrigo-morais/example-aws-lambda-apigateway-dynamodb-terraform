'use strict'

const AWS = require('aws-sdk')
const uuid = require('uuid')
const documentClient = new AWS.DynamoDB.DocumentClient()

exports.handler = (event, context, callback) => {
  const params = {
    TableName: process.env.TABLE_NAME
  }

  documentClient.scan(params, (error, data) => error ? callback(error, data) : callback(error, data.Items))
}
