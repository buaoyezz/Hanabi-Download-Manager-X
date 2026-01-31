import { makeStyles, tokens, Title2, Text, Table, TableHeader, TableRow, TableHeaderCell, TableBody, TableCell, Badge } from '@fluentui/react-components';
import { Checkmark24Filled, ArrowUp24Filled, Flash24Filled, Star24Filled } from '@fluentui/react-icons';
import { useTranslation } from 'react-i18next';
import { motion } from 'framer-motion';

const useStyles = makeStyles({
  section: {
    padding: '120px 48px',
    backgroundColor: tokens.colorNeutralBackground2,
  },
  header: {
    textAlign: 'center',
    marginBottom: '80px',
    maxWidth: '800px',
    margin: '0 auto 80px',
  },
  title: {
    fontSize: 'clamp(2rem, 4vw, 3rem)',
    fontWeight: '800',
    color: tokens.colorNeutralForeground1,
    marginBottom: '16px',
    letterSpacing: '-0.02em',
  },
  description: {
    fontSize: '1.125rem',
    color: tokens.colorNeutralForeground2,
    lineHeight: '1.7',
  },
  tableContainer: {
    maxWidth: '1300px',
    margin: '0 auto',
    boxShadow: '0 12px 48px rgba(0, 0, 0, 0.12)',
    borderRadius: '24px',
    overflow: 'hidden',
    backgroundColor: tokens.colorNeutralBackground1,
    border: `2px solid ${tokens.colorNeutralStroke2}`,
  },
  tableWrapper: {
    overflowX: 'auto',
  },
  styledTable: {
    width: '100%',
    '& thead': {
      background: `linear-gradient(135deg, ${tokens.colorBrandBackground2}, ${tokens.colorBrandBackground})`,
    },
    '& th': {
      padding: '24px 20px',
      fontWeight: '700',
      fontSize: '16px',
      color: tokens.colorNeutralForeground1,
      borderBottom: `3px solid ${tokens.colorBrandForeground1}`,
      textAlign: 'left',
    },
    '& td': {
      padding: '20px',
      fontSize: '15px',
      borderBottom: `1px solid ${tokens.colorNeutralStroke2}`,
      transition: 'background-color 0.2s ease',
    },
    '& tbody tr': {
      transition: 'all 0.2s ease',
      ':hover': {
        backgroundColor: tokens.colorNeutralBackground2,
        transform: 'scale(1.01)',
      },
    },
    '& tbody tr:last-child td': {
      borderBottom: 'none',
    },
  },
  highlightCell: {
    fontWeight: '700',
    color: tokens.colorBrandForeground1,
  },
  betterBadge: {
    display: 'inline-flex',
    alignItems: 'center',
    gap: '8px',
    padding: '6px 12px',
    backgroundColor: tokens.colorPaletteGreenBackground2,
    borderRadius: '8px',
    fontWeight: '600',
  },
  note: {
    padding: '32px',
    textAlign: 'center',
    backgroundColor: tokens.colorNeutralBackground2,
    borderTop: `2px solid ${tokens.colorNeutralStroke2}`,
  },
  noteText: {
    color: tokens.colorNeutralForeground3,
    fontStyle: 'italic',
    fontSize: '14px',
  },
});

const Comparison = () => {
  const styles = useStyles();
  const { t } = useTranslation();

  return (
    <section id="comparison" className={styles.section}>
      <div className={styles.header}>
        <Title2 className={styles.title}>{t('comparison.title')}</Title2>
                <br />
        <Text className={styles.description}>
          {t('comparison.description', { defaultValue: '全方位对比，看看我们的进步' })}
        </Text>
      </div>

      <motion.div
        className={styles.tableContainer}
        initial={{ opacity: 0, y: 40 }}
        whileInView={{ opacity: 1, y: 0 }}
        viewport={{ once: true }}
        transition={{ duration: 0.6 }}
      >
        <div className={styles.tableWrapper}>
          <Table size="medium" aria-label="Version Comparison" className={styles.styledTable}>
            <TableHeader>
              <TableRow>
                <TableHeaderCell>{t('comparison.columns.item')}</TableHeaderCell>
                <TableHeaderCell>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <Star24Filled style={{ color: tokens.colorPaletteYellowForeground1 }} />
                    {t('comparison.columns.hdmx')}
                  </div>
                </TableHeaderCell>
                <TableHeaderCell>{t('comparison.columns.hdm')}</TableHeaderCell>
                <TableHeaderCell>{t('comparison.columns.x')}</TableHeaderCell>
                <TableHeaderCell>{t('comparison.columns.improvement')}</TableHeaderCell>
              </TableRow>
            </TableHeader>
            <TableBody>
              <TableRow>
                <TableCell><strong>{t('comparison.rows.speed')}</strong></TableCell>
                <TableCell className={styles.highlightCell}>
                  <span className={styles.betterBadge}>
                    <Flash24Filled style={{ fontSize: '18px' }} />
                    {t('comparison.values.faster')}
                  </span>
                </TableCell>
                <TableCell>{t('comparison.values.slower')}</TableCell>
                <TableCell>
                  <Badge appearance="filled" color="success" icon={<Checkmark24Filled />}>
                    {t('comparison.values.better')}
                  </Badge>
                </TableCell>
                <TableCell>
                  <Badge appearance="filled" color="important" icon={<ArrowUp24Filled />}>
                    {t('comparison.values.significant')}
                  </Badge>
                </TableCell>
              </TableRow>
              <TableRow>
                <TableCell><strong>{t('comparison.rows.aesthetics')}</strong></TableCell>
                <TableCell className={styles.highlightCell}>
                  <span className={styles.betterBadge}>
                    <Checkmark24Filled style={{ fontSize: '18px' }} />
                    Flutter
                  </span>
                </TableCell>
                <TableCell>Python</TableCell>
                <TableCell>
                  <Badge appearance="filled" color="success" icon={<Checkmark24Filled />}>
                    {t('comparison.values.better')}
                  </Badge>
                </TableCell>
                <TableCell>
                  <Badge appearance="filled" color="important" icon={<ArrowUp24Filled />}>
                    {t('comparison.values.significant')}
                  </Badge>
                </TableCell>
              </TableRow>
              <TableRow>
                <TableCell><strong>{t('comparison.rows.architecture')}</strong></TableCell>
                <TableCell className={styles.highlightCell}>
                  <span className={styles.betterBadge}>
                    <Checkmark24Filled style={{ fontSize: '18px' }} />
                    {t('comparison.values.modular')}
                  </span>
                </TableCell>
                <TableCell>{t('comparison.values.semiModular')}</TableCell>
                <TableCell>
                  <Badge appearance="filled" color="success" icon={<Checkmark24Filled />}>
                    {t('comparison.values.better')}
                  </Badge>
                </TableCell>
                <TableCell>
                  <Badge appearance="filled" color="warning">{t('comparison.values.moderate')}</Badge>
                </TableCell>
              </TableRow>
              <TableRow>
                <TableCell><strong>{t('comparison.rows.scheduling')}</strong></TableCell>
                <TableCell className={styles.highlightCell}>
                  <span className={styles.betterBadge}>
                    <Checkmark24Filled style={{ fontSize: '18px' }} />
                    {t('comparison.values.excellent')}
                  </span>
                </TableCell>
                <TableCell>{t('comparison.values.average')}</TableCell>
                <TableCell>
                  <Badge appearance="filled" color="success" icon={<Checkmark24Filled />}>
                    {t('comparison.values.slightlyBetter')}
                  </Badge>
                </TableCell>
                <TableCell>
                  <Badge appearance="filled" color="informative">{t('comparison.values.slight')}</Badge>
                </TableCell>
              </TableRow>
              <TableRow>
                <TableCell><strong>{t('comparison.rows.core')}</strong></TableCell>
                <TableCell className={styles.highlightCell}>
                  <span className={styles.betterBadge}>
                    <Checkmark24Filled style={{ fontSize: '18px' }} />
                    NSFX/Soda
                  </span>
                </TableCell>
                <TableCell>NSF</TableCell>
                <TableCell>
                  <Badge appearance="filled" color="success" icon={<Checkmark24Filled />}>
                    {t('comparison.values.better')}
                  </Badge>
                </TableCell>
                <TableCell>
                  <Badge appearance="filled" color="important" icon={<ArrowUp24Filled />}>
                    {t('comparison.values.significant')}
                  </Badge>
                </TableCell>
              </TableRow>
              <TableRow>
                <TableCell><strong>{t('comparison.rows.release')}</strong></TableCell>
                <TableCell className={styles.highlightCell}>2026</TableCell>
                <TableCell>2023</TableCell>
                <TableCell>----------</TableCell>
                <TableCell>----------</TableCell>
              </TableRow>
            </TableBody>
          </Table>
        </div>
        <div className={styles.note}>
          <Text className={styles.noteText}>
            {t('comparison.note')}
          </Text>
        </div>
      </motion.div>
    </section>
  );
};

export default Comparison;
