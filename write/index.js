'use strict'

const AWS = require('aws-sdk')
const uuid = require('uuid')
const documentClient = new AWS.DynamoDB.DocumentClient()

exports.handler = async (event, context, callback) => {
  const params = {
    Item: {
      "id": uuid.v1(),
      "name": JSON.parse(event.body).name
                                                },
    TableName: process.env.TABLE_NAME
  }

  try {
    await documentClient.put(params).promise()

    console.log(`createMovie data=${JSON.stringify(event.body)}`);

    callback(null, {
      isBase64Encoded: false,
      statusCode: 201,
      headers: { 'Access-Control-Allow-Origin': '*' },
      body: JSON.stringify(event.body)
    })
  } catch (error) {
    console.log(`createMovie ERROR=${error.stack}`);

    callback(null, {
      isBase64Encoded: false,
      statusCode: 422,
      headers: { 'Access-Control-Allow-Origin': '*' },
      body: JSON.stringify({
        Title: 'Unprocessable Entity',
        Detail: `Entity invalid to create movies ${error.stack}`,
        Entyti: event.body,
        Params: params
      })
    })
  }
}
