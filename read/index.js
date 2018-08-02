'use strict'

const AWS = require('aws-sdk')
const uuid = require('uuid')
const documentClient = new AWS.DynamoDB.DocumentClient()

const params = {
  TableName: process.env.TABLE_NAME
}

exports.handler = async (event, context) => {
  try {
    const data = await documentClient.scan(params).promise()
    if (!data || typeof data === 'undefined' || !data.Items) {
      return {
        statusCode: 404,
        errorTitle: 'Not Found',
        errorDetail: 'Movies not found'
      }
    } else {
      console.log(`readMovies data=${JSON.stringify(data.Items)}`);
      return {
        isBase64Encoded: false,
        statusCode: 200,
        headers: { 'Access-Control-Allow-Origin': '*' },
        body: JSON.stringify(data.Items)
      }
    }
  } catch (error) {
    console.log(`readMovies ERROR=${error.stack}`);
    return {
      statusCode: 400,
      errorTitle: 'Bad Request',
      errorDetail: `Error to find movies ${error.stack}`
    }
  }
}
