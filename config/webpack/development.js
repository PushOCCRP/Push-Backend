process.env.NODE_ENV = process.env.NODE_ENV || 'development'

const environment = require('./environment')

module.exports = environment.toWebpackConfig()

// devServer: { host: '0.0.0.0', port: '7654', hot: true, inline: true, disableHostCheck: true, public: '0.0.0.0:0' },
