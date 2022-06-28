import type { ReactNode } from 'react';

interface IconListTitleProps {
  children?: ReactNode;

  className?: string;
}

function IconListTitle({ children, className }: IconListTitleProps) {
  const classes = ['usa-icon-list__title', className].filter(Boolean).join(' ');

  return <h3 className={classes}>{children}</h3>;
}

export default IconListTitle;
