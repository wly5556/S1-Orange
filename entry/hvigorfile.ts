import { hapTasks, OhosHapContext, OhosPluginId } from '@ohos/hvigor-ohos-plugin'
import { hvigor, getNode } from '@ohos/hvigor'
import { execSync } from 'node:child_process'

const rootNode = getNode(__filename)

rootNode.afterNodeEvaluate(node => {
    const hapContext = node.getContext(OhosPluginId.OHOS_HAP_PLUGIN) as OhosHapContext
    const buildProfileOpt = hapContext.getBuildProfileOpt()

    const buildDate = new Date().toLocaleString()

    let gitHeadHash = '(未包含git环境的构建)'
    let gitHeadDate = '(未包含git环境的构建)'
    try {
        gitHeadHash = execSync('git rev-parse HEAD', { timeout: 5000 }).toString().trim()
        gitHeadDate = execSync('git --no-pager log -1 --pretty="format:%cd" --date="format:%Y/%m/%d %H:%M:%S"', { timeout: 5000 }).toString().trim()
    } catch (error) {
        console.warn('Error retrieving git commit hash:', error.message)
    }

    buildProfileOpt['buildOption']['arkOptions']['buildProfileFields']['buildDate'] = buildDate
    buildProfileOpt['buildOption']['arkOptions']['buildProfileFields']['gitHeadHash'] = gitHeadHash
    buildProfileOpt['buildOption']['arkOptions']['buildProfileFields']['gitHeadDate'] = gitHeadDate

    hapContext.setBuildProfileOpt(buildProfileOpt)
})

export default {
    system: hapTasks,  /* Built-in plugin of Hvigor. It cannot be modified. */
    plugins:[]         /* Custom plugin to extend the functionality of Hvigor. */
}
