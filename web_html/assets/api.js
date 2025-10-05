class GitHubAPI {
    constructor(username = 'buaoyezz') {
        this.username = username;
        this.baseUrl = 'https://api.github.com';
        this.cache = new Map();
        this.cacheTimeout = 5 * 60 * 1000;
    }

    async fetchRepositories(options = {}) {
        const {
            page = 1,
            perPage = 30,
            sort = 'updated',
            direction = 'desc',
            type = 'owner'
        } = options;

        const cacheKey = `repos_${page}_${perPage}_${sort}_${direction}_${type}`;
        const cached = this.cache.get(cacheKey);
        
        if (cached && Date.now() - cached.timestamp < this.cacheTimeout) {
            return cached.data;
        }

        try {
            const url = `${this.baseUrl}/users/${this.username}/repos?page=${page}&per_page=${perPage}&sort=${sort}&direction=${direction}&type=${type}`;
            const response = await fetch(url);
            
            if (!response.ok) {
                throw new Error(`GitHub API error: ${response.status}`);
            }
            
            const data = await response.json();
            
            this.cache.set(cacheKey, {
                data,
                timestamp: Date.now()
            });
            
            return data;
        } catch (error) {
            console.error('Failed to fetch repositories:', error);
            throw error;
        }
    }

    async fetchRepository(repoName) {
        const cacheKey = `repo_${repoName}`;
        const cached = this.cache.get(cacheKey);
        
        if (cached && Date.now() - cached.timestamp < this.cacheTimeout) {
            return cached.data;
        }

        try {
            const url = `${this.baseUrl}/repos/${this.username}/${repoName}`;
            const response = await fetch(url);
            
            if (!response.ok) {
                throw new Error(`GitHub API error: ${response.status}`);
            }
            
            const data = await response.json();
            
            this.cache.set(cacheKey, {
                data,
                timestamp: Date.now()
            });
            
            return data;
        } catch (error) {
            console.error(`Failed to fetch repository ${repoName}:`, error);
            throw error;
        }
    }

    async fetchLanguages(repoName) {
        const cacheKey = `languages_${repoName}`;
        const cached = this.cache.get(cacheKey);
        
        if (cached && Date.now() - cached.timestamp < this.cacheTimeout) {
            return cached.data;
        }

        try {
            const url = `${this.baseUrl}/repos/${this.username}/${repoName}/languages`;
            const response = await fetch(url);
            
            if (!response.ok) {
                throw new Error(`GitHub API error: ${response.status}`);
            }
            
            const data = await response.json();
            
            this.cache.set(cacheKey, {
                data,
                timestamp: Date.now()
            });
            
            return data;
        } catch (error) {
            console.error(`Failed to fetch languages for ${repoName}:`, error);
            return {};
        }
    }

    filterRepositories(repos, filters = {}) {
        const {
            excludeForks = true,
            requireDescription = true,
            minStars = 0,
            excludeArchived = true,
            languages = [],
            excludeNames = []
        } = filters;

        return repos.filter(repo => {
            if (excludeForks && repo.fork) return false;
            if (requireDescription && !repo.description) return false;
            if (repo.stargazers_count < minStars) return false;
            if (excludeArchived && repo.archived) return false;
            if (languages.length > 0 && !languages.includes(repo.language)) return false;
            if (excludeNames.includes(repo.name)) return false;
            
            return true;
        });
    }

    mapRepositoryToProject(repo, languages = {}) {
        const languageList = Object.keys(languages).slice(0, 3);
        const tags = this.getProjectTags(repo, languageList);
        
        return {
            id: repo.id,
            name: repo.name,
            title: repo.name.replace(/-/g, ' ').replace(/\b\w/g, l => l.toUpperCase()),
            description: repo.description || '暂无描述',
            url: repo.html_url,
            homepage: repo.homepage,
            language: repo.language,
            languages: languageList,
            stars: repo.stargazers_count,
            forks: repo.forks_count,
            updated: repo.updated_at,
            created: repo.created_at,
            tags: tags,
            category: this.getCategoryFromTags(tags)
        };
    }

    getProjectTags(repo, languages) {
        const tags = [];
        
        if (repo.language) {
            tags.push(repo.language);
        }
        
        languages.forEach(lang => {
            if (lang !== repo.language && tags.length < 3) {
                tags.push(lang);
            }
        });
        
        const name = repo.name.toLowerCase();
        const desc = (repo.description || '').toLowerCase();
        
        if (name.includes('ui') || name.includes('component') || desc.includes('界面') || desc.includes('ui')) {
            tags.push('UI框架');
        }
        if (name.includes('tool') || desc.includes('工具') || desc.includes('tool')) {
            tags.push('工具');
        }
        if (name.includes('web') || desc.includes('web') || languages.includes('JavaScript') || languages.includes('TypeScript')) {
            tags.push('Web');
        }
        if (name.includes('ai') || name.includes('ml') || desc.includes('ai') || desc.includes('机器学习')) {
            tags.push('AI');
        }
        if (name.includes('download') || desc.includes('下载') || desc.includes('download')) {
            tags.push('下载工具');
        }
        if (name.includes('note') || desc.includes('笔记') || desc.includes('note')) {
            tags.push('笔记工具');
        }
        
        return tags.slice(0, 3);
    }

    getCategoryFromTags(tags) {
        if (tags.some(tag => ['JavaScript', 'TypeScript', 'HTML', 'CSS', 'Web'].includes(tag))) {
            return 'web';
        }
        if (tags.some(tag => ['AI', '机器学习'].includes(tag))) {
            return 'ai';
        }
        return 'tool';
    }

    clearCache() {
        this.cache.clear();
    }
}

window.GitHubAPI = GitHubAPI;